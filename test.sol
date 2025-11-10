// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ---- IMPORTS ----
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// ---- INTERFAZ UNISWAP V2 MOCK ----
interface IUniswapV2Router {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

// ---- CONTRATO PRINCIPAL ----
contract KipuBankV3 is Ownable, ReentrancyGuard {
    IUniswapV2Router public immutable router;
    address public immutable USDC; // dirección del USDC

    uint256 public immutable withdrawLimit;  
    uint256 public immutable bankCap;       

    uint256 public totalETHDeposits;
    uint256 public totalUSDCDeposits;

    mapping(address => uint256) public userETHBalances;
    mapping(address => uint256) public userUSDCBalances;

    // ---- EVENTOS ----
    event DepositETH(address indexed user, uint256 amount);
    event DepositUSDC(address indexed user, uint256 amount);
    event WithdrawETH(address indexed user, uint256 amount);
    event WithdrawUSDC(address indexed user, uint256 amount);

    // ---- CONSTRUCTOR ----
    constructor(
        address _router,
        address _usdc,
        uint256 _withdrawLimit,
        uint256 _bankCap
    ) Ownable(msg.sender) {
        router = IUniswapV2Router(_router);
        USDC = _usdc;
        withdrawLimit = _withdrawLimit;
        bankCap = _bankCap;
    }

    // ---- DEPÓSITO DE ETH ----
    function depositETH() external payable nonReentrant {
        require(msg.value > 0, "Monto invalido");
        require(totalETHDeposits + msg.value <= bankCap, "Capacidad del banco alcanzada");

        userETHBalances[msg.sender] += msg.value;
        totalETHDeposits += msg.value;

        emit DepositETH(msg.sender, msg.value);
    }

    // ---- DEPÓSITO DE TOKENS (USDC o swap a USDC) ----
    function depositToken(address token, uint256 amount) external nonReentrant {
        require(amount > 0, "Monto invalido");

        if(token == USDC) {
            // depósito directo de USDC
            require(totalUSDCDeposits + amount <= bankCap, "Capacidad del banco alcanzada");

            IERC20(token).transferFrom(msg.sender, address(this), amount);
            userUSDCBalances[msg.sender] += amount;
            totalUSDCDeposits += amount;

            emit DepositUSDC(msg.sender, amount);
        } else {
            // swap a USDC
            IERC20(token).transferFrom(msg.sender, address(this), amount);
            uint256 usdcReceived = swapTokenToUSDC(token, amount);

            require(totalUSDCDeposits + usdcReceived <= bankCap, "Capacidad del banco alcanzada");

            userUSDCBalances[msg.sender] += usdcReceived;
            totalUSDCDeposits += usdcReceived;

            emit DepositUSDC(msg.sender, usdcReceived);
        }
    }

    // ---- FUNCION INTERNA DE SWAP ----
    function swapTokenToUSDC(address token, uint256 amount) internal returns (uint256) {
        IERC20(token).approve(address(router), amount);

        // Declaración correcta del array de direcciones en memoria
     // Correct declaration of the path array
    address[] memory path = new address[](2);
    path[0] = token;
    path[1] = USDC;

    uint[] memory amounts = router.swapExactTokensForTokens(
        amount,
        0, // accepts any minimum amount (not recommended for production)
        path,
        address(this),
        block.timestamp
    );

    return amounts[1];
}

    // ---- RETIRO ETH ----
    function withdrawETH(uint256 amount) external nonReentrant {
        require(amount <= withdrawLimit, "Excede limite por transaccion");
        require(userETHBalances[msg.sender] >= amount, "Saldo insuficiente");

        userETHBalances[msg.sender] -= amount;
        totalETHDeposits -= amount;

        (bool sent, ) = msg.sender.call{value: amount}("");
        require(sent, "Fallo transferencia ETH");

        emit WithdrawETH(msg.sender, amount);
    }

    // ---- RETIRO USDC ----
    function withdrawUSDC(uint256 amount) external nonReentrant {
        require(amount <= withdrawLimit, "Excede limite por transaccion");
        require(userUSDCBalances[msg.sender] >= amount, "Saldo insuficiente");

        userUSDCBalances[msg.sender] -= amount;
        totalUSDCDeposits -= amount;

        IERC20(USDC).transfer(msg.sender, amount);

        emit WithdrawUSDC(msg.sender, amount);
    }

    // ---- CONSULTA DE SALDOS ----
    function getBalanceETH(address user) external view returns (uint256) {
        return userETHBalances[user];
    }

    function getBalanceUSDC(address user) external view returns (uint256) {
        return userUSDCBalances[user];
    }
}



