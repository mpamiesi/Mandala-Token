// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MiToken is ERC20 {
    uint256 public txMax = 100;
    uint256 public walletMax = 1000;
    uint256 public taxBuy = 2;
    uint256 public taxSell = 3;
    address public automatedMarketPair;
    address public marketingWallet;
    mapping (address => bool) public isExcludedFromFees;
    mapping (address => bool) public isWhitelisted;
    mapping (address => bool) public isBlacklisted;
    uint256 public totalTaxes;

    constructor() ERC20("Mi Token", "MIT") {
        _mint(msg.sender, 1000000000 * 10 ** decimals());
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), allowance(sender, _msgSender()) - amount);
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual override {
        require(sender != address(0), "Transferencia desde la dirección 0x0");
        require(recipient != address(0), "Transferencia hacia la dirección 0x0");
        require(amount > 0, "Monto de transferencia debe ser mayor que 0");
        require(balanceOf(sender) >= amount, "Saldo insuficiente para la transferencia");
        require(balanceOf(recipient) + amount <= walletMax, "La billetera del destinatario ha alcanzado el límite máximo");
        require(!isBlacklisted[sender], "La dirección del remitente está en la lista negra");
        require(!isBlacklisted[recipient], "La dirección del destinatario está en la lista negra");
        
        uint256 taxAmount = calculateTaxAmount(amount);
        uint256 transferAmount = amount - taxAmount;
        
        if (taxAmount > 0) {
            totalTaxes += taxAmount;
            _burn(sender, taxAmount);
        }
        
        _transfer(sender, automatedMarketPair, taxAmount / 2);
        _transfer(sender, marketingWallet, taxAmount / 2);
        _transfer(sender, recipient, transferAmount);
    }
    
    function calculateTaxAmount(uint256 amount) public view returns (uint256) {
        if (isExcludedFromFees[msg.sender]) {
            return 0;
        }
        
        if (totalSupply() == 0 || automatedMarketPair == address(0)) {
            return 0;
        }
        
        if (msg.sender == automatedMarketPair) {
            return (amount * taxBuy) / 100;
        } else {
            return (amount * taxSell) / 100;
        }
    }
    
    function excludeFromFees(address account) public {
        require(msg.sender == _owner, "Solo el propietario puede llamar a esta función");
        isExcludedFromFees[account] = true;
    }
    
    function includeInFees(address account) public{
require(msg.sender == _owner, "Solo el propietario puede llamar a esta función");
isExcludedFromFees[account] = false;
}

function excludeMultipleFromFees(address[] calldata accounts) public {
    require(msg.sender == _owner, "Solo el propietario puede llamar a esta función");
    for (uint256 i = 0; i < accounts.length; i++) {
        isExcludedFromFees[accounts[i]] = true;
    }
}

function includeMultipleInFees(address[] calldata accounts) public {
    require(msg.sender == _owner, "Solo el propietario puede llamar a esta función");
    for (uint256 i = 0; i < accounts.length; i++) {
        isExcludedFromFees[accounts[i]] = false;
    }
}

function renounceOwnership() public virtual override {
    revert("No se puede renunciar a la propiedad en este contrato");
}

function setAutomatedMarketPair(address pair) public {
    require(msg.sender == _owner, "Solo el propietario puede llamar a esta función");
    automatedMarketPair = pair;
}

function setMarketingWallet(address wallet) public {
    require(msg.sender == _owner, "Solo el propietario puede llamar a esta función");
    marketingWallet = wallet;
}

function transferOwnership(address newOwner) public virtual override {
    require(msg.sender == _owner, "Solo el propietario puede llamar a esta función");
    _transferOwnership(newOwner);
}

function pauseTrade() public {
    require(msg.sender == _owner, "Solo el propietario puede llamar a esta función");
    _pause();
}

function unpauseTrade() public {
    require(msg.sender == _owner, "Solo el propietario puede llamar a esta función");
    _unpause();
}

function whitelist(address account) public {
    require(msg.sender == _owner, "Solo el propietario puede llamar a esta función");
    isWhitelisted[account] = true;
}

function unwhitelist(address account) public {
    require(msg.sender == _owner, "Solo el propietario puede llamar a esta función");
    isWhitelisted[account] = false;
}

function blacklist(address account) public {
    require(msg.sender == _owner, "Solo el propietario puede llamar a esta función");
    isBlacklisted[account] = true;
}

function unblacklist(address account) public {
    require(msg.sender == _owner, "Solo el propietario puede llamar a esta función");
    isBlacklisted[account] = false;
}

function getTaxes() public view returns (uint256) {
    return totalTaxes;
}

