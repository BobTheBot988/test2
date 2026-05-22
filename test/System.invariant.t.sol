// SPDX-License-Identifier: GPL-3.0 or above
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Auction} from "../src/Auction.sol";
import {ZPunks} from "../src/impls/RealNFT.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {SymTest} from "halmos-cheatcodes/SymTest.sol";

contract SystemInvariantTest is Test, SymTest {
    Auction public auction;
    ZPunks public nft;
    ERC20Mock public token;

    // --- GHOST STATE ---
    uint256 public ghost_bidSum;
    address public ghost_max_bidder;
    uint256 public ghost_nbid;
    address public ghost_winner;
    bool public ghost_has_finished;
    uint256 public ghost_n_iterations;

    address[] public bidders;
    address public owner;

    mapping(address => uint256) public ghost_bids;

    // --- STRUTTURE PER IL FUZZING BOUNDED ---
    enum ActionType {
        BID,
        FINISH,
        NOOP
    }

    struct Action {
        uint8 actionType;
        uint256 amount;
        uint256 bidderSeed;
    }

    // Spostato da constructor a setUp per totale compatibilità con Halmos
    function setUp() public {
        token = new ERC20Mock();
        ghost_nbid = 0;
        ghost_n_iterations = 0;
        ghost_has_finished = false;

        // Ridotto a 3 bidder per evitare lo State Explosion su Halmos,
        // mantenendo comunque la competizione tra utenti.
        for (uint256 i = 0; i < 3; i++) {
            address bidder = makeAddr(string(abi.encodePacked("bidder", i)));
            bidders.push(bidder);
            token.mint(bidder, 100_000);
        }

        owner = makeAddr("owner");
        nft = new ZPunks(owner);

        instantiate_auction();
    }

    function instantiate_auction() internal {
        vm.startPrank(owner);
        nft.safeMint(owner, "");

        // Passiamo ghost_n_iterations come tokenId corrente
        auction = new Auction(
            IERC20(address(token)),
            IERC721(address(nft)),
            ghost_n_iterations,
            owner,
            block.timestamp,
            block.timestamp + 7 days
        );

        nft.approve(address(auction), ghost_n_iterations);
        vm.stopPrank();
    }

    // --- ENTRYPOINT UNICO PER HALMOS ---
    function check_SystemInvariants(Action[4] memory actions) public {
        vm.assume(actions[0].actionType <= 2);
        vm.assume(actions[1].actionType <= 2);
        vm.assume(actions[2].actionType <= 2);
        vm.assume(actions[3].actionType <= 2);
        for (uint256 i = 0; i < actions.length; i++) {
            Action memory action = actions[i];
            ActionType act = ActionType(action.actionType);

            // Selezione deterministica/simbolica del bidder dall'array
            uint256 bidderIndex = action.bidderSeed % bidders.length;
            address currentBidder = bidders[bidderIndex];

            if (act == ActionType.BID) {
                _executeBid(currentBidder, action.amount);
            } else if (act == ActionType.FINISH) {
                _executeFinish(currentBidder);
            }
            // Se ActionType.NOOP non fa nulla (permette sequenze più corte)

            // Controlla le invarianti alla fine di OGNI transazione della sequenza
            _assertInvariants();
        }
        _executeFinish(owner);
        instantiate_auction();
    }

    // Definiamo una sequenza di 4 azioni consecutive nello stesso stato
    // --- ENTRYPOINT UNICO PER FOUNDRY---
    function test_SystemInvariants(Action[4] memory actions) public {
        vm.assume(actions[0].actionType <= 2);
        vm.assume(actions[1].actionType <= 2);
        vm.assume(actions[2].actionType <= 2);
        vm.assume(actions[3].actionType <= 2);
        for (uint256 i = 0; i < actions.length; i++) {
            Action memory action = actions[i];
            ActionType act = ActionType(action.actionType);

            // Selezione deterministica/simbolica del bidder dall'array
            uint256 bidderIndex = action.bidderSeed % bidders.length;
            address currentBidder = bidders[bidderIndex];

            if (act == ActionType.BID) {
                _test_executeBid(currentBidder, action.amount);
            } else if (act == ActionType.FINISH) {
                _test_executeFinish(currentBidder);
            }
            // Se ActionType.NOOP non fa nulla (permette sequenze più corte)

            // Controlla le invarianti alla fine di OGNI transazione della sequenza
            _assertInvariants();
        }
        _test_executeFinish(owner);
        instantiate_auction();
    }

    // --- LOGICA DI ESECUZIONE DELLE AZIONI ---

    function _executeBid(address bidder, uint256 amount) internal {
        // Evitiamo bid superiori al bilancio o pari a zero per non sporcare i path puliti
        vm.assume(amount > 0 && amount <= 100_000);

        vm.startPrank(bidder);
        // Approviamo l'asta a prelevare i token ERC20 del bidder
        token.approve(address(auction), amount);

        // Il try/catch assicura che aggiorniamo lo stato ghost SOLO se l'asta accetta il bid
        if (ghost_has_finished) {
            vm.stopPrank();
            return;
        }
        auction.bid(amount);
        ghost_nbid += 1;
        ghost_bids[bidder] += amount;
        ghost_bidSum += amount;

        if (ghost_max_bidder == address(0) || ghost_bids[bidder] > ghost_bids[ghost_max_bidder]) {
            ghost_max_bidder = bidder;
        }

        vm.stopPrank();
    }

    function _executeFinish(address caller) internal {
        // entro la sequenza limitata a 4 step totali.

        // Saltiamo oltre i 7 giorni per far scadere l'asta
        vm.warp(block.timestamp + 7 days + 1);

        vm.startPrank(caller);
        if (ghost_has_finished) {
            vm.stopPrank();
            return;
        }

        address winner = auction.finishAuction();
        ghost_winner = winner;
        ghost_has_finished = true;

        // Per testare la "prossima iterazione", incrementiamo il contatore
        // e prepariamo la nuova asta nello stesso slot di esecuzione
        ghost_n_iterations += 1;
        // instantiate_auction();

        vm.stopPrank();
    }

    function _test_executeBid(address bidder, uint256 amount) internal {
        // Evitiamo bid superiori al bilancio o pari a zero per non sporcare i path puliti
        vm.assume(amount > 0 && amount <= 100_000);

        vm.startPrank(bidder);
        // Approviamo l'asta a prelevare i token ERC20 del bidder
        token.approve(address(auction), amount);

        // Il try/catch assicura che aggiorniamo lo stato ghost SOLO se l'asta accetta il bid
        if (ghost_has_finished) {
            vm.expectRevert(Auction.AlreadyFinished.selector);
            auction.bid(amount);
            vm.stopPrank();
            return;
        }
        auction.bid(amount);
        ghost_nbid += 1;
        ghost_bids[bidder] += amount;
        ghost_bidSum += amount;

        if (ghost_max_bidder == address(0) || ghost_bids[bidder] > ghost_bids[ghost_max_bidder]) {
            ghost_max_bidder = bidder;
        }

        vm.stopPrank();
    }

    function _test_executeFinish(address caller) internal {
        // entro la sequenza limitata a 4 step totali.

        // Saltiamo oltre i 7 giorni per far scadere l'asta
        vm.warp(block.timestamp + 7 days + 1);

        vm.startPrank(caller);
        if (ghost_has_finished) {
            vm.expectRevert(Auction.AlreadyFinished.selector);
            auction.finishAuction();
            vm.stopPrank();
            return;
        }

        address winner = auction.finishAuction();
        ghost_winner = winner;
        ghost_has_finished = true;

        // Per testare la "prossima iterazione", incrementiamo il contatore
        // e prepariamo la nuova asta nello stesso slot di esecuzione
        ghost_n_iterations += 1;
        // instantiate_auction();

        vm.stopPrank();
    }

    // --- LE TUE INVARIANTI COMPILATE ---
    function _assertInvariants() internal view {
        // Ripristinato il tuo test sui bid mappati
        // Se l'asta è stata conclusa con successo, verifica il vincitore e l'NFT
        if (ghost_has_finished && ghost_winner != address(0)) {
            assert(ghost_max_bidder == ghost_winner);

            // Verifica che il vincitore abbia ricevuto l'NFT dell'iterazione precedente (quella conclusa)
            uint256 completedAuctionId = ghost_n_iterations - 1;
            assert(ghost_winner == nft.ownerOf(completedAuctionId));
        }
    }
}

