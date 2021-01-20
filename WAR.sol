// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./Include.sol";

contract WAR is ERC20UpgradeSafe, Configurable {
	function __WAR_init(address governor_, address mine_) external initializer {
        __Context_init_unchained();
		__ERC20_init_unchained("WeStarter", "WAR");
		__Governable_init_unchained(governor_);
		__WAR_init_unchained(mine_);
	}
	
	function __WAR_init_unchained(address mine_) public governance {
		_mint(mine_, 150000 * 10 ** uint256(decimals()));
	}
	
}

