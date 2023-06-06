// SPDX-License-Identifier: GPL-3.0
// Docgen-SOLC: 0.8.15

pragma solidity ^0.8.15;

import {Test} from "forge-std/Test.sol";
import {BalancerGaugeAdapter, SafeERC20, IERC20, IERC20Metadata, Math, IGauge, IStrategy} from "../../../../../src/vault/adapter/balancer/BalancerGaugeAdapter.sol";
import {BalancerLpCompounder, BalancerUtils, IBalancerVault, BatchSwapStruct} from "../../../../../src/vault/strategy/compounder/balancer/BalancerLpCompounder.sol";
import {Clones} from "openzeppelin-contracts/proxy/Clones.sol";
import {MockStrategyClaimer} from "../../../../utils/mocks/MockStrategyClaimer.sol";

contract BalancerLpCompounderTest is Test {
    address _vault = address(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    BalancerGaugeAdapter adapter;

    address asset;
    address lpToken1;
    address bal;

    bytes4[8] sigs;
    BatchSwapStruct[][] toBaseAssetPaths;
    uint256[] minTradeAmounts;

    function setUp() public {
        uint256 forkId = vm.createSelectFork(vm.rpcUrl("polygon"));
        vm.selectFork(forkId);

        IGauge gauge = IGauge(_gauge);
        asset = gauge.stake();
        lpToken = ILpToken(asset);
        bal = gauge.rewards(2);
        lpToken0 = lpToken.token0();
        lpToken1 = lpToken.token1();

        toBaseAssetPaths.push();
        toBaseAssetPaths[0].push(Route(bal, lpToken1, false));

        toAssetPaths.push();
        toAssetPaths[0].push(Route(lpToken1, lpToken0, false));

        minTradeAmounts.push(uint256(1));

        bytes memory stratData = abi.encode(
            op,
            router,
            toBaseAssetPaths,
            toAssetPaths,
            minTradeAmounts,
            abi.encode("")
        );

        address impl = address(new BalancerGaugeAdapter());

        adapter = BalancerGaugeAdapter(Clones.clone(impl));

        adapter.initialize(
            abi.encode(
                asset,
                address(this),
                new BalancerLpCompounder(),
                0,
                sigs,
                stratData
            ),
            address(gauge),
            abi.encode(address(gauge))
        );
    }

    function test__init() public {
        assertEq(
            IERC20(address(baseAsset)).allowance(
                address(adapter),
                address(vault)
            ),
            type(uint256).max
        );

        assertEq(
            IERC20(address(asset)).allowance(address(adapter), address(gauge)),
            type(uint256).max
        );
    }

    function test__compound() public {
        deal(address(asset), address(this), 1e18);
        IERC20(address(asset)).approve(address(adapter), type(uint256).max);
        adapter.deposit(1e18, address(this));

        uint256 oldTa = adapter.totalAssets();

        vm.roll(block.number + 10_000);
        vm.warp(block.timestamp + 150_000);

        adapter.harvest();

        assertGt(adapter.totalAssets(), oldTa);
    }

    function test__claim() public {
        address bob = address(0x2e234DAe75C793f67A35089C9d99245E1C58470b);

        deal(address(asset), address(this), 1e18);
        IERC20(address(asset)).approve(address(adapter), type(uint256).max);
        adapter.deposit(1e18, address(this));

        vm.roll(block.number + 10_000);
        vm.warp(block.timestamp + 150_000);

        vm.prank(bob);

        adapter.claim();

        assertGt(IERC20(bal).balanceOf(address(adapter)), 0);
    }
}
