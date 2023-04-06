// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC20, Ownable {
    uint256 private constant MAX = ~uint256(0);
    uint256 private constant _totalSupply = 1000000000 * 10**18; // 1 billion tokens
    uint256 private _reflectedSupply = (MAX - (MAX % _totalSupply));
    uint256 private _maxTxAmount = _totalSupply / 100; // 1% of the total supply
    uint256 private _maxWalletAmount = _totalSupply / 50; // 2% of the total supply
    address private _automatedMarketPair;
    address private _marketingWallet;
    mapping(address => bool) private isWhitelisted;
    mapping(address => bool) private isBlacklisted;
    bool private antiBotEnabled;
    uint256 private antiBotStartTime;

    event AntiBotEnabled();
    event Recovered(address token, uint256 amount);

    constructor(address automatedMarketPair, address marketingWallet) ERC20("MyToken", "MTK") {
        _mint(_msgSender(), _totalSupply);
        _automatedMarketPair = automatedMarketPair;
        _marketingWallet = marketingWallet;
        isWhitelisted[_msgSender()] = true;
        isWhitelisted[automatedMarketPair] = true;
    }

    function setMaxTxAmount(uint256 maxTxAmount) external onlyOwner {
        require(maxTxAmount > 0, "El monto máximo de transacción debe ser mayor que 0");
        _maxTxAmount = maxTxAmount;
    }

    function setMaxWalletAmount(uint256 maxWalletAmount) external onlyOwner {
        require(maxWalletAmount > 0, "El límite máximo de tokens por billetera debe ser mayor que 0");
        _maxWalletAmount = maxWalletAmount;
    }

    function setAutomatedMarketPair(address automatedMarketPair) external onlyOwner {
        require(automatedMarketPair != address(0), "La dirección del par de mercado automatizado no puede ser 0x0");
        _automatedMarketPair = automatedMarketPair;
        isWhitelisted[automatedMarketPair] = true;
    }

    function setMarketingWallet(address marketingWallet) external onlyOwner {
        require(marketingWallet != address(0), "La dirección de la billetera de marketing no puede ser 0x0");
        _marketingWallet = marketingWallet;
    }

    function excludeFromFees(address account) public onlyOwner {
        isWhitelisted[account] = true;
    }

    function excludeMultipleAccountsFromFees(address[] memory accounts) public onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            isWhitelisted[accounts[i]] = true;
        }
    }

    function blacklist(address account) public onlyOwner {
        isBlacklisted[account] = true;
    }

    function blacklistMultiple(address[] memory accounts) public onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            isBlacklisted[accounts[i]] = true;
        }
    }

    function antiBot() public payable {
        require(msg.value >= 1 ether, "Debes enviar al menos 1 ETH para utilizar esta función");
        _marketingWallet.transfer(msg.value);
           antiBotStartTime = block.timestamp;
    antiBotEnabled = true;
    emit AntiBotEnabled();
}

function getTaxes() external view returns (uint256 buyTax, uint256 sellTax) {
    buyTax = 10;
    sellTax = 15;
}

function renounceOwnership() public override onlyOwner {
    revert("No se puede renunciar a la propiedad del contrato");
}

function transferOwnership(address newOwner) public override onlyOwner {
    require(newOwner != address(0), "La nueva dirección del propietario no puede ser 0x0");
    super.transferOwnership(newOwner);
}

function pauseTrade() external onlyOwner {
    _pause();
}

function unpauseTrade() external onlyOwner {
    _unpause();
}

function isExcludedFromFees(address account) public view returns (bool) {
    return isWhitelisted[account];
}

function isBlacklistedAddress(address account) public view returns (bool) {
    return isBlacklisted[account];
}

function _transfer(address sender, address recipient, uint256 amount) internal override {
    require(sender != address(0), "La dirección del remitente no puede ser 0x0");
    require(recipient != address(0), "La dirección del destinatario no puede ser 0x0");
    require(amount > 0, "El monto de la transferencia debe ser mayor que 0");
    require(!_paused, "Las transferencias están en pausa");
    require(!isBlacklisted[sender], "El remitente está en la lista negra");
    require(!isBlacklisted[recipient], "El destinatario está en la lista negra");
    require(!antiBotEnabled || block.timestamp > antiBotStartTime + 1 minutes || isWhitelisted[sender], "Debes utilizar la función antiBot antes de poder transferir tokens");

    if (sender != owner() && recipient != owner()) {
        require(amount <= _maxTxAmount, "El monto de la transacción excede el límite máximo");
        require(balanceOf(recipient) + amount <= _maxWalletAmount, "El destinatario ya tiene el límite máximo de tokens en su billetera");
    }

    uint256 transferAmount = amount;

    if (!isExcludedFromFees(sender) && !isExcludedFromFees(recipient)) {
        uint256 buyTax = 10;
        uint256 sellTax = 15;
        if (recipient == _automatedMarketPair) {
            sellTax = 20;
        }
        uint256 taxAmount = amount * buyTax / 100;
        transferAmount -= taxAmount;
        _reflectedSupply -= taxAmount * 2;
        emit Transfer(sender, address(this), taxAmount);
        if (recipient != _automatedMarketPair) {
            taxAmount = amount * sellTax / 100;
            transferAmount -= taxAmount;
            _reflectedSupply -= taxAmount * 2;
            emit Transfer(sender, address(this), taxAmount);
        }
    }

    _transferStandard(sender, recipient, transferAmount);
}

function _transferStandard(address sender, address recipient, uint256 amount) private {
    uint256 rAmount = amount * _reflectedSupply / _totalSupply;
    _balances[sender] -= amount;
    _balances[recipient] += amount;
    _reflectedBalances[sender] -= rAmount;
    _reflectedBalances[recipient] += rAmount;
    emit Transfer(sender, recipient, amount);
}

function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
    IERC20(tokenAddress).transfer(owner(), tokenAmount);
    emit Recovered(tokenAddress, tokenAmount);
}

function setAutomatedMarketPair(address pair, bool value) external onlyOwner {
    require(pair != address(0), "La dirección del par de mercado automatizado no puede ser 0x0");
    require(pair != uniswapV2Pair, "No puedes deshabilitar el par de mercado uniswap");
    require(isWhitelisted[pair], "El par de mercado automatizado debe estar en la lista blanca");
    require(value != automatedMarketPairEnabled, "El par de mercado automatizado ya está configurado en el valor especificado");
    automatedMarketPairEnabled = value;
    emit AutomatedMarketPairUpdated(pair, value);
}

function setMarketingWallet(address payable wallet) external onlyOwner {
    require(wallet != address(0), "La dirección de la billetera de marketing no puede ser 0x0");
    marketingWallet = wallet;
    emit MarketingWalletUpdated(wallet);
}

function addWhitelistedAddress(address account) external onlyOwner {
    require(account != address(0), "La dirección de la cuenta no puede ser 0x0");
    isWhitelisted[account] = true;
    emit WhitelistedAddressAdded(account);
}

function removeWhitelistedAddress(address account) external onlyOwner {
    require(account != address(0), "La dirección de la cuenta no puede ser 0x0");
    isWhitelisted[account] = false;
    emit WhitelistedAddressRemoved(account);
}

function addBlacklistedAddress(address account) external onlyOwner {
    require(account != address(0), "La dirección de la cuenta no puede ser 0x0");
    isBlacklisted[account] = true;
    emit BlacklistedAddressAdded(account);
}

function removeBlacklistedAddress(address account) external onlyOwner {
    require(account != address(0), "La dirección de la cuenta no puede ser 0x0");
    isBlacklisted[account] = false;
    emit BlacklistedAddressRemoved(account);
}

receive() external payable {}

event AntiBotEnabled();
event AutomatedMarketPairUpdated(address indexed pair, bool indexed value);
event MarketingWalletUpdated(address indexed wallet);
event WhitelistedAddressAdded(address indexed account);
event WhitelistedAddressRemoved(address indexed account);
event BlacklistedAddressAdded(address indexed account);
event BlacklistedAddressRemoved(address indexed account);
event Recovered(address token, uint256 amount);

}
