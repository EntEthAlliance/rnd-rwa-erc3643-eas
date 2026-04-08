// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IValenceKernelRouting} from "../valence/ValenceEASKernelAdapter.sol";

contract MockValenceKernelRouting is IValenceKernelRouting {
    SelectorRoute[] private _routes;

    function applySelectorRoutes(SelectorRoute[] calldata routes) external {
        delete _routes;
        for (uint256 i = 0; i < routes.length; i++) {
            _routes.push(routes[i]);
        }
    }

    function routeCount() external view returns (uint256) {
        return _routes.length;
    }

    function routeAt(uint256 index) external view returns (bytes4 selector, address module) {
        SelectorRoute memory route = _routes[index];
        return (route.selector, route.module);
    }
}
