# KipuBankV2

## Resumen
KipuBankV2_Final es la versión mejorada del contrato original KipuBank desarrollada como parte del Trabajo Final del Módulo 2.
Esta versión introduce control de acceso avanzado, soporte multi-token (ETH + ERC20), oráculos Chainlink para conversión de valores, contabilidad interna en USDC (6 decimales), y medidas adicionales de seguridad y observabilidad.
En esta versión de KipuBankV2, opté por usar OpenZeppelin (Ownable) para implementar control de acceso seguro y permitir una gestión centralizada de permisos.
El soporte multi-token (ETH y ERC20) amplía la utilidad del contrato al permitir depósitos y retiros de distintos activos.
El uso de Chainlink Price Feeds garantiza conversión confiable y descentralizada entre ETH/USD, aportando precisión y seguridad en la contabilidad interna.
Además, incorporé eventos, errores personalizados y estructuras optimizadas siguiendo buenas prácticas de Solidity (checks-effects-interactions, variables immutable, mappings anidados) para mayor seguridad, eficiencia y trazabilidad.

## Mejoras claves implementadas

- Entrega & Verificación: Contrato desplegado y verificado correctamente en la red Sepolia (enlaces abajo).
- Control de Acceso: Sistema de roles usando Ownable y un rol adicional ROLE_MANAGER con funciones grantRole / revokeRole.
- Soporte Multi-token: Maneja depósitos y retiros en ETH (address(0)), USDC, y otros ERC20s configurables.
- Oráculos Chainlink: Feed ETH/USD y feeds adicionales por token para conversión a USDC.
(Aporta +2 pts.)
- Contabilidad en USDC: Todos los saldos internos se expresan en unidades USDC (6 decimales) para mantener uniformidad.
- Seguridad: Incluye Pausable y ReentrancyGuard de OpenZeppelin.
- Eventos y Errores personalizados: Facilitan trazabilidad y debugging.
- Documentación NatSpec.

## Cómo desplegar (Remix)

1. Abrir Remix y crear `src/KipuBankV2_Final.sol`.
2. Compilar con Solidity **0.8.20**.
3. Constructor parámetros (ejemplo para Sepolia):
   - `_withdrawLimitUsdc`: `1000000` (1 USDC, 6 decimals)
   - `_bankCapUsdc`: `10000000` (10 USDC, 6 decimals)
   - `_ethUsdPriceFeed`: `0x694AA1769357215DE4FAC081bf1f309aDC325306` 
4. Deploy y verificar en Etherscan.

## Instrucciones de uso 
- `depositETH()` — depositar ETH (msg.value).  
- `depositUSDC(amount)` — depositar USDC token (user debe aprobar).  
- `depositERC20(token, amount)` — depositar token ERC20 (owner debe haber registrado feed con `setTokenPriceFeed`).  
- `withdrawUSDC(amountUsdc)` — retirar en USDC (intento de transferencia del token USDC si configurado, si no devuelve equivalente en ETH).
- setTokenPriceFeed(token, feed)	(Solo owner) Configura feed Chainlink para un nuevo token.
- pause() / unpause()	Habilita o detiene el contrato temporalmente.


## Dirección del contrato (Sepolia)
Dirección del contrato:
0x236aDE80a31556142eC405020F60dF7E09D9e277
https://sepolia.etherscan.io/address/0x236ade80a31556142ec405020f60df7e09d9e277

Red:
Sepolia Testnet

Verificación:

https://repo.sourcify.dev/11155111/0x236aDE80a31556142eC405020F60dF7E09D9e277/
Routescan verification successful.

https://testnet.routescan.io/address/0x236aDE80a31556142eC405020F60dF7E09D9e277/contract/11155111/code

Transacción de despliegue:
https://sepolia.etherscan.io/tx/0x633207c20d369d350cda5999023fb4a7eb0feb0e8876223b1afe071a09f9d2db

