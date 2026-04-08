// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IValenceKernelRouting} from "../valence/ValenceEASKernelAdapter.sol";

contract MockValenceKernelRouting is IValenceKernelRouting {
    mapping(bytes4 => address) private _moduleBySelector;
    bytes4[] private _selectors;
    mapping(bytes4 => uint256) private _selectorIndexPlusOne;

    function applySelectorRoutes(SelectorRoute[] calldata routes) external {
        for (uint256 i = 0; i < _selectors.length; i++) {
            bytes4 selector = _selectors[i];
            _moduleBySelector[selector] = address(0);
            _selectorIndexPlusOne[selector] = 0;
        }
        delete _selectors;

        for (uint256 i = 0; i < routes.length; i++) {
            _setRoute(routes[i].selector, routes[i].module);
        }
    }

    function applySelectorRouteDelta(SelectorRoute[] calldata replacements, bytes4[] calldata removals) external {
        for (uint256 i = 0; i < replacements.length; i++) {
            _setRoute(replacements[i].selector, replacements[i].module);
        }

        for (uint256 i = 0; i < removals.length; i++) {
            _removeRoute(removals[i]);
        }
    }

    function routeCount() external view returns (uint256) {
        return _selectors.length;
    }

    function routeAt(uint256 index) external view returns (bytes4 selector, address module) {
        selector = _selectors[index];
        return (selector, _moduleBySelector[selector]);
    }

    function moduleForSelector(bytes4 selector) external view returns (address) {
        return _moduleBySelector[selector];
    }

    function _setRoute(bytes4 selector, address module) internal {
        require(module != address(0), "module=0");

        if (_selectorIndexPlusOne[selector] == 0) {
            _selectors.push(selector);
            _selectorIndexPlusOne[selector] = _selectors.length;
        }

        _moduleBySelector[selector] = module;
    }

    function _removeRoute(bytes4 selector) internal {
        uint256 idxPlusOne = _selectorIndexPlusOne[selector];
        if (idxPlusOne == 0) return;

        uint256 idx = idxPlusOne - 1;
        uint256 last = _selectors.length - 1;
        bytes4 moved = _selectors[last];

        if (idx != last) {
            _selectors[idx] = moved;
            _selectorIndexPlusOne[moved] = idx + 1;
        }

        _selectors.pop();
        _selectorIndexPlusOne[selector] = 0;
        _moduleBySelector[selector] = address(0);
    }
}
