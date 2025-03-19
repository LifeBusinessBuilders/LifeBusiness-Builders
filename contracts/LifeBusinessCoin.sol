// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/interfaces/IERC165.sol";

/**
 * @title LifeBusinessCoin
 * @dev This contract defines a token with a hard minting cap (MINT_CAP),
 * a flexible total supply cap (totalSupplyCap), and controlled minting mechanisms.
 *
 * - `MINT_CAP` is a fixed, unchangeable cap on the total token supply.
 * - `totalSupplyCap` is a flexible cap that can be adjusted within the `MINT_CAP` limit.
 * - Minting is controlled by a governor with restrictions on amounts and frequency.
 * - The contract ensures transparency and fairness in token issuance and modifications.
 * - Governance has the ability to adjust the minting limit, period, and total supply cap as needed.
 * 
 * The contract is upgradeable via the UUPS (Universal Upgradeable Proxy Standard) pattern
 * and follows OpenZeppelin's security best practices.
 *
 * Licensed under the Apache-2.0 License. See LICENSE file for details.
 */

contract LifeBusinessCoin is
    Initializable,
    ERC20Upgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 public constant MAX_SUPPLY = 10_000_000 * 10 ** 18;
    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 10 ** 18;
    uint256 public constant MIN_MINTING_PERIOD = 7 days; // 7 days between mints
    uint256 public constant MAX_MINT_PER_PERIOD = 100_000 * 10 ** 18;
    uint256 public constant MINT_CAP = 50_000_000 * 10 ** 18; // The hard minting cap. Cannot be exceeded.

    uint256 public totalMinted;
    bool public mintingAllowed;
    uint256 public lastMintTime;
    uint256 public nextMintTime;
    uint256 public mintingLimit;
    uint256 public mintingPeriod;
    uint256 public totalSupplyCap;

    address public multiSigWallet;

    event TokensMinted(address indexed to, uint256 amount);
    event MintingLimitUpdated(uint256 newLimit);
    event MintingPeriodUpdated(uint256 newPeriod);
    event GovernanceAction(address indexed governor, string action, uint256 value);
    event ContractInitialized(address multiSigWallet, uint256 initialSupply);
    event MintingCapUpdated(uint256 newCap);
    event TotalSupplyCapUpdated(uint256 newCap);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers(); // Disable initializers to prevent direct deployment
    }

    function initialize(address _multiSigWallet) public initializer {
        require(_multiSigWallet != address(0), "Invalid multi-sig wallet address");

        __ERC20_init("LifeBusiness Coin", "LBCO");
        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        multiSigWallet = _multiSigWallet;
        totalMinted = INITIAL_SUPPLY;
        mintingAllowed = true;
        mintingPeriod = 60 days;
        lastMintTime = block.timestamp;
        nextMintTime = lastMintTime + mintingPeriod;
        mintingLimit = 100_000 * 10 ** 18;
        totalSupplyCap = 20_000_000 * 10 ** 18;

        _grantRole(DEFAULT_ADMIN_ROLE, multiSigWallet);
        _grantRole(GOVERNOR_ROLE, multiSigWallet);
        _grantRole(MINTER_ROLE, multiSigWallet);

        _mint(multiSigWallet, INITIAL_SUPPLY);
        emit ContractInitialized(_multiSigWallet, INITIAL_SUPPLY);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(GOVERNOR_ROLE)
    {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlUpgradeable)
        returns (bool)
{
    return
        interfaceId == type(IERC20).interfaceId || // ERC20 interface 
        interfaceId == type(IAccessControl).interfaceId || // AccessControl interface
        interfaceId == type(UUPSUpgradeable).interfaceId || // UUPS interface 
        super.supportsInterface(interfaceId);
}
  
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) nonReentrant {
        require(mintingAllowed, "Minting is currently disabled.");
        require(amount > 0, "Mint amount must be greater than zero.");
        require(totalMinted + amount <= totalSupplyCap, "Exceeds the total supply cap.");
        require(amount <= mintingLimit, "Exceeds minting limit.");
        require(amount <= MAX_MINT_PER_PERIOD, "Exceeds max minting per period.");
        require(block.timestamp >= nextMintTime, "Minting cooldown active.");

        uint256 mintAmount = amount;

        if (mintAmount > 0) {
            _mint(to, mintAmount);
            totalMinted += mintAmount;
            lastMintTime = block.timestamp;
            nextMintTime = lastMintTime + mintingPeriod;
            emit TokensMinted(to, mintAmount);
        }
    }

    function setMintingLimit(uint256 newLimit) external onlyRole(GOVERNOR_ROLE) {
        require(newLimit > 0, "Minting limit must be greater than zero.");
        require(newLimit <= MINT_CAP, "Minting limit cannot exceed MINT_CAP.");
        mintingLimit = newLimit;
        emit MintingLimitUpdated(newLimit);
        emit GovernanceAction(msg.sender, "Minting Limit Update", newLimit);
    }

    function setMintingPeriod(uint256 newPeriod) external onlyRole(GOVERNOR_ROLE) {
        require(newPeriod >= MIN_MINTING_PERIOD, "Minting period must be at least 7 days.");
        mintingPeriod = newPeriod;
        nextMintTime = lastMintTime + newPeriod;
        emit MintingPeriodUpdated(newPeriod);
        emit GovernanceAction(msg.sender, "Minting Period Update", newPeriod);
    }

    function setTotalSupplyCap(uint256 newCap) external onlyRole(GOVERNOR_ROLE) {
        require(newCap <= MINT_CAP, "New cap cannot exceed the hard minting cap.");
        require(newCap > totalSupply(), "New cap must be greater than current total supply");
        totalSupplyCap = newCap;
        emit TotalSupplyCapUpdated(newCap); // Emit event after updating the cap
        emit GovernanceAction(msg.sender, "Total Supply Cap Update", newCap);
    }
}