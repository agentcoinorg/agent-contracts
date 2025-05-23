// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AgentFactoryTestUtils} from "../helpers/AgentFactoryTestUtils.sol";
import {AgentLaunchPool} from "../../src/AgentLaunchPool.sol";

contract AgentLaunchPoolClaimWithETHCollateralTest is AgentFactoryTestUtils {
    
    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));

        _deployDefaultContracts();
    }

    function test_canClaimForSelf() public { 
        address user = makeAddr("user");
        vm.deal(user, 100 ether);

        (AgentLaunchPool pool,) = _deployDefaultLaunchPool(address(0));

        vm.startPrank(user);
        pool.depositETH{value: 1 ether}();

        vm.warp(block.timestamp + timeWindow);

        pool.launch();

        IERC20 agentToken = IERC20(pool.agentToken());
    
        assertEq(pool.hasLaunched(), true);

        assertEq(agentToken.balanceOf(user), 0);

        assertEq(pool.claim(user), true);

        assertEq(agentToken.balanceOf(user), launchPoolAmount);
    }

    function test_canClaimForBeneficiary() public { 
        address user = makeAddr("user");
        vm.deal(user, 100 ether);

        (AgentLaunchPool pool,) = _deployDefaultLaunchPool(address(0));

        vm.startPrank(user);
        pool.depositETH{value: 1 ether}();

        vm.warp(block.timestamp + timeWindow);

        pool.launch();

        assertEq(pool.hasLaunched(), true);

        vm.stopPrank();

        IERC20 agentToken = IERC20(pool.agentToken());

        assertEq(agentToken.balanceOf(user), 0);
        assertEq(agentToken.balanceOf(makeAddr("anon")), 0);

        vm.prank(makeAddr("anon"));
        assertEq(pool.claim(user), true);

        assertEq(agentToken.balanceOf(user), launchPoolAmount);
        assertEq(agentToken.balanceOf(makeAddr("anon")), 0);
    }

    function test_canClaimIfMultipleDeposits() public { 
        address user = makeAddr("user");
        vm.deal(user, 100 ether);

        (AgentLaunchPool pool,) = _deployDefaultLaunchPool(address(0));

        vm.startPrank(user);
        pool.depositETH{value: 1 ether}();
        pool.depositETH{value: 2 ether}();

        vm.warp(block.timestamp + timeWindow);

        pool.launch();

        IERC20 agentToken = IERC20(pool.agentToken());

        assertEq(pool.hasLaunched(), true);

        assertEq(agentToken.balanceOf(user), 0);
       
        assertEq(pool.claim(user), true);

        assertEq(agentToken.balanceOf(user), launchPoolAmount);
    }

    function test_depositBeneficiaryCanClaim() public { 
        address user = makeAddr("user");
        vm.deal(user, 100 ether);

        (AgentLaunchPool pool,) = _deployDefaultLaunchPool(address(0));

        vm.startPrank(user);
        pool.depositETHFor{value: 1 ether}(makeAddr("beneficiary"));

        vm.warp(block.timestamp + timeWindow);

        pool.launch();

        assertEq(pool.hasLaunched(), true);

        IERC20 agentToken = IERC20(pool.agentToken());

        assertEq(agentToken.balanceOf(user), 0);
        assertEq(agentToken.balanceOf(makeAddr("beneficiary")), 0);
       
        assertEq(pool.claim(makeAddr("beneficiary")), true);

        assertEq(agentToken.balanceOf(user), 0);
        assertEq(agentToken.balanceOf(makeAddr("beneficiary")), launchPoolAmount);
    }

    function test_canMultiClaim() public { 
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        address user3 = makeAddr("user3");
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);

        (AgentLaunchPool pool,) = _deployDefaultLaunchPool(address(0));

        vm.prank(user1);
        pool.depositETH{value: 1 ether}();

        vm.prank(user2);
        pool.depositETH{value: 2 ether}();

        vm.prank(user3);
        pool.depositETH{value: 2 ether}();

        vm.warp(block.timestamp + timeWindow);

        pool.launch();

        assertEq(pool.hasLaunched(), true);

        IERC20 agentToken = IERC20(pool.agentToken());

        assertEq(agentToken.balanceOf(user1), 0);
        assertEq(agentToken.balanceOf(user2), 0);
        assertEq(agentToken.balanceOf(user3), 0);
       
        address[] memory users = new address[](3);
        users[0] = user1;
        users[1] = user2;
        users[2] = user3;

        pool.multiClaim(users);
        
        assertEq(agentToken.balanceOf(user1), 1 * launchPoolAmount / 5);
        assertEq(agentToken.balanceOf(user2), 2 * launchPoolAmount / 5);
        assertEq(agentToken.balanceOf(user3), 2 * launchPoolAmount / 5);
    }

    function test_multipleUsersCanClaim() public { 
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        address user3 = makeAddr("user3");
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);

        (AgentLaunchPool pool,) = _deployDefaultLaunchPool(address(0));

        vm.prank(user1);
        pool.depositETH{value: 1 ether}();

        vm.prank(user2);
        pool.depositETH{value: 2 ether}();

        vm.prank(user3);
        pool.depositETH{value: 2 ether}();

        vm.warp(block.timestamp + timeWindow);

        pool.launch();

        assertEq(pool.hasLaunched(), true);

        IERC20 agentToken = IERC20(pool.agentToken());

        assertEq(agentToken.balanceOf(user1), 0);
        assertEq(agentToken.balanceOf(user2), 0);
        assertEq(agentToken.balanceOf(user3), 0);
       
        assertEq(pool.claim(user1), true);
        assertEq(pool.claim(user2), true);
        assertEq(pool.claim(user3), true);
        
        assertEq(agentToken.balanceOf(user1), 1 * launchPoolAmount / 5);
        assertEq(agentToken.balanceOf(user2), 2 * launchPoolAmount / 5);
        assertEq(agentToken.balanceOf(user3), 2 * launchPoolAmount / 5);
    }

    function test_forbidsReentrantClaiming() public { 
        address user = makeAddr("user");
        vm.deal(user, 100 ether);

        (AgentLaunchPool pool,) = _deployDefaultLaunchPool(address(0));

        vm.startPrank(user);
        pool.depositETH{value: 1 ether}();

        vm.warp(block.timestamp + timeWindow);

        pool.launch();

        IERC20 agentToken = IERC20(pool.agentToken());
    
        assertEq(pool.hasLaunched(), true);

        assertEq(agentToken.balanceOf(user), 0);

        assertEq(pool.claim(user), true);
        assertEq(pool.claim(user), false);

        assertEq(agentToken.balanceOf(user), launchPoolAmount);
    }

    function test_forbidsClaimingIfBeneficiaryAlreadyClaimed() public { 
        address user = makeAddr("user");
        vm.deal(user, 100 ether);

        (AgentLaunchPool pool,) = _deployDefaultLaunchPool(address(0));

        vm.prank(user);
        pool.depositETH{value: 1 ether}();

        vm.warp(block.timestamp + timeWindow);

        pool.launch();

        IERC20 agentToken = IERC20(pool.agentToken());
    
        assertEq(pool.hasLaunched(), true);

        assertEq(agentToken.balanceOf(user), 0);

        vm.prank(makeAddr("anon1"));
        assertEq(pool.claim(user), true);
        vm.prank(makeAddr("anon2"));
        assertEq(pool.claim(user), false);

        assertEq(agentToken.balanceOf(user), launchPoolAmount);
    }

    function test_forbidsClaimingBeforeLaunch() public { 
        address user = makeAddr("user");
        vm.deal(user, 100 ether);

        (AgentLaunchPool pool,) = _deployDefaultLaunchPool(address(0));

        vm.prank(user);
        pool.depositETH{value: 1 ether}();

        vm.prank(user);
        vm.expectRevert(AgentLaunchPool.NotLaunched.selector);
        pool.claim(user);

        vm.warp(block.timestamp + timeWindow);

        pool.launch();

        IERC20 agentToken = IERC20(pool.agentToken());
    
        assertEq(agentToken.balanceOf(user), 0);
    }

    function test_forbidsClaimingForBeneficiaryBeforeLaunch() public { 
        address user = makeAddr("user");
        vm.deal(user, 100 ether);

        (AgentLaunchPool pool,) = _deployDefaultLaunchPool(address(0));

        vm.prank(user);
        pool.depositETH{value: 1 ether}();

        vm.prank(makeAddr("anon"));
        vm.expectRevert(AgentLaunchPool.NotLaunched.selector);
        pool.claim(user);

        vm.warp(block.timestamp + timeWindow);

        pool.launch();

        IERC20 agentToken = IERC20(pool.agentToken());
    
        assertEq(agentToken.balanceOf(user), 0);
    }

    function test_forbidsMultiClaimingBeforeLaunch() public { 
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        address user3 = makeAddr("user3");
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);

        (AgentLaunchPool pool,) = _deployDefaultLaunchPool(address(0));

        vm.prank(user1);
        pool.depositETH{value: 1 ether}();

        vm.prank(user2);
        pool.depositETH{value: 2 ether}();

        vm.prank(user3);
        pool.depositETH{value: 2 ether}();
               
        address[] memory users = new address[](3);
        users[0] = user1;
        users[1] = user2;
        users[2] = user3;

        vm.expectRevert(AgentLaunchPool.NotLaunched.selector);
        pool.multiClaim(users);

        vm.warp(block.timestamp + timeWindow);

        pool.launch();

        assertEq(pool.hasLaunched(), true);

        IERC20 agentToken = IERC20(pool.agentToken());

        assertEq(agentToken.balanceOf(user1), 0);
        assertEq(agentToken.balanceOf(user2), 0);
        assertEq(agentToken.balanceOf(user3), 0);
    }

    function test_forbidsClaimingIfBeneficiaryNeverDeposited() public { 
        address user = makeAddr("user");
        vm.deal(user, 100 ether);

        (AgentLaunchPool pool,) = _deployDefaultLaunchPool(address(0));

        vm.startPrank(user);
        pool.depositETH{value: 1 ether}();

        vm.warp(block.timestamp + timeWindow);

        pool.launch();

        IERC20 agentToken = IERC20(pool.agentToken());
    
        assertEq(pool.hasLaunched(), true);

        assertEq(agentToken.balanceOf(user), 0);

        assertEq(pool.claim(makeAddr("anon")), false);

        assertEq(agentToken.balanceOf(user), 0);
        assertEq(agentToken.balanceOf(makeAddr("anon")), 0);

        assertEq(pool.claim(user), true);

        assertEq(agentToken.balanceOf(makeAddr("anon")), 0);
        assertEq(agentToken.balanceOf(user), launchPoolAmount);
    }
}

