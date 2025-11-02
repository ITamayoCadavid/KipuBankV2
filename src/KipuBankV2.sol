// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ---- INTERFAZ CHAINLINK ----
interface AggregatorV3Interface {
    function decimals() external view returns (uint8);
    function description() external view returns (string memory);
    function version() external view returns (uint256);
    function getRoundData(uint80 _roundId)
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

// ---- IMPORTS ----
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// ---- CONTRATO PRINCIPAL ----
contract KipuBankV2 is Ownable {

    // ---- VARIABLES ----
    AggregatorV3Interface public immutable priceFeed;
    uint256 public immutable withdrawLimit; // Límite máximo de retiro
    uint256 public immutable bankCap;       // Tope global del banco
    uint256 public totalDeposits;           // Contador global

    mapping(address => mapping(address => uint256)) private balances; // usuario => token => saldo

    // ---- EVENTOS ----
    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdraw(address indexed user, address indexed token, uint256 amount);

    // ---- CONSTRUCTOR ----
    constructor(
        address _priceFeed,      // Dirección del oráculo Chainlink ETH/USD
        uint256 _withdrawLimit,  // Límite máximo de retiro
        uint256 _bankCap         // Tope global del banco
    ) Ownable(msg.sender) {
        priceFeed = AggregatorV3Interface(_priceFeed);
        withdrawLimit = _withdrawLimit;
        bankCap = _bankCap;
    }

    // ---- DEPÓSITO DE ETHER ----
    function depositETH() external payable {
        require(msg.value > 0, "Monto invalido");
        require(totalDeposits + msg.value <= bankCap, "Capacidad del banco alcanzada");

        balances[msg.sender][address(0)] += msg.value;
        totalDeposits += msg.value;

        emit Deposit(msg.sender, address(0), msg.value);
    }

    // ---- RETIRO DE ETHER ----
    function withdrawETH(uint256 amount) external {
        require(amount <= withdrawLimit, "Excede el limite por transaccion");
        require(balances[msg.sender][address(0)] >= amount, "Saldo insuficiente");

        balances[msg.sender][address(0)] -= amount;
        totalDeposits -= amount;

        payable(msg.sender).transfer(amount);

        emit Withdraw(msg.sender, address(0), amount);
    }

    // ---- DEPÓSITO DE TOKEN ERC20 ----
    function depositToken(address token, uint256 amount) external {
        require(amount > 0, "Monto invalido");
        require(totalDeposits + amount <= bankCap, "Capacidad del banco alcanzada");

        IERC20(token).transferFrom(msg.sender, address(this), amount);

        balances[msg.sender][token] += amount;
        totalDeposits += amount;

        emit Deposit(msg.sender, token, amount);
    }

    // ---- RETIRO DE TOKEN ERC20 ----
    function withdrawToken(address token, uint256 amount) external {
        require(amount <= withdrawLimit, "Excede el limite por transaccion");
        require(balances[msg.sender][token] >= amount, "Saldo insuficiente");

        balances[msg.sender][token] -= amount;
        totalDeposits -= amount;

        IERC20(token).transfer(msg.sender, amount);

        emit Withdraw(msg.sender, token, amount);
    }

    // ---- FUNCIÓN ORÁCULO ----
    function getLatestPrice() public view returns (int) {
        (, int price, , , ) = priceFeed.latestRoundData();
        return price; // precio ETH/USD con 8 decimales
    }

    // ---- CONSULTA DE SALDO ----
    function getBalance(address user, address token) external view returns (uint256) {
        return balances[user][token];
    }
}


