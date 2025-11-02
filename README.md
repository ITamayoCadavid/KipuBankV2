# KipuBankV2

## Resumen
KipuBankV2_Final es la versión final mejorada del contrato original KipuBank para el Trabajo Final del Módulo 3.  
Incluye control por roles, soporte multi-token (ETH + ERC20s), oráculos Chainlink para conversión a USD, contabilidad interna en USDC (6 decimales), y protecciones (pausable, reentrancy).

## Mejoras claves implementadas
- **Entrega & Verificación:** contrato verificado en Sepolia (link abajo).
- **Control de Acceso:** `owner` + sistema simple de roles (`ROLE_MANAGER`) con `grantRole`/`revokeRole`. (Cumple +2 pts si se justifica).
- **Soporte Multi-token:** ETH (`address(0)`), USDC (configurable) y otros ERC20s (owner debe configurar feed Chainlink). (2 tokens => +2 pts).
- **Chainlink Price Feeds:** ETH/USD feed y feeds por token para conversión a USDC (aporta +2 pts).
- **Contabilidad en USDC:** balances internos en USDC units (6 decimals) para homogénea contabilidad.
- **Pausable & ReentrancyGuard:** `paused` flag y `nonReentrant` protection included (mejora seguridad).
- **Eventos y Errores personalizados** para observabilidad.
- **NatSpec** en el contrato para documentación técnica.

## Archivos


## Cómo desplegar (Remix)
1. Abrir Remix y crear `src/KipuBankV2_Final.sol`.
2. Compilar con Solidity **0.8.26**.
3. Constructor parámetros (ejemplo para Sepolia):
   - `_withdrawLimitUsdc`: `1000000` (1 USDC, 6 decimals)
   - `_bankCapUsdc`: `10000000` (10 USDC, 6 decimals)
   - `_ethUsdPriceFeed`: `0x694AA1769357215DE4FAC081bf1f309aDC325306` (Sepolia example)
4. Deploy y verificar en Etherscan como en entregas anteriores.

## Instrucciones de uso 
- `depositETH()` — depositar ETH (msg.value).  
- `depositUSDC(amount)` — depositar USDC token (user debe aprobar).  
- `depositERC20(token, amount)` — depositar token ERC20 (owner debe haber registrado feed con `setTokenPriceFeed`).  
- `withdrawUSDC(amountUsdc)` — retirar en USDC (intento de transferencia del token USDC si configurado, si no devuelve equivalente en ETH).


## Dirección del contrato (Sepolia)
Etherscan verification skipped: API key not found in global Settings.
Sourcify verification successful.
https://repo.sourcify.dev/11155111/0x236aDE80a31556142eC405020F60dF7E09D9e277/
Routescan verification successful.
https://testnet.routescan.io/address/0x236aDE80a31556142eC405020F60dF7E09D9e277/contract/11155111/code
Dirección del contrato desplegado:
0x236aDE80a31556142eC405020F60dF7E09D9e277

Red utilizada:
Sepolia Testnet

Contrato verificado en:
🔹 Sourcify

🔹 Routescan

Sourcify 
 https://repo.sourcify.dev/11155111/0x236aDE80a31556142eC405020F60dF7E09D9e277/

Routescan 
 https://testnet.routescan.io/address/0x236aDE80a31556142eC405020F60dF7E09D9e277/contract/11155111/code

## Autora
Isabela Tamayo 
