# Implementacion Core AccountID

Documento de referencia para la evolucion del core hacia un modelo basado en `AccountID`.

## Problema

El proyecto venia mezclando tres tipos de identidad:

- `client`
- `userid`
- `SteamID2`

Eso complica el diseño porque:

- `client` y `userid` son identidades de sesion
- `SteamID2` es una representacion textual
- ninguna de esas tres es la mejor llave interna para memoria o SQL

## Decision

El core adopta esta regla:

- `AccountID` es la identidad canonica interna
- `SteamID2` se deriva solo para presentacion

## Implicaciones

### En runtime

El core debe trabajar con:

- `callerAccountId`
- `targetAccountId`
- `sessionId`

Y solo convertir a `SteamID2` cuando haga falta escribir un log legible o mostrar informacion a un usuario.

### En SQL

Las tablas del proyecto usan:

- `caller_account_id`
- `target_account_id`
- `caller_steamid64` en MySQL
- `target_steamid64` en MySQL

`SteamID2` deja de ser una llave persistente.

La regla queda asi:

- runtime y contratos por `AccountID`
- salida legible por `SteamID2`
- persistencia analitica MySQL por `AccountID` y `SteamID64`
- bootstrap local SQLite sin `SteamID64`

### En API

La direccion del contrato publico es:

- exponer sesiones, lifecycle e identidad por `AccountID`
- usar `sessionId` como referencia publica de contexto
- evitar contratos duplicados para el mismo ciclo de voto

## Modelo del core

El core debe entender una votacion como una sesion con:

- identidad del caller
- identidad del target
- tipo de voto
- argumento bruto
- estado
- resultado
- conteo observado

Eso evita que plugins externos reconstruyan el ciclo de voto a partir de eventos sueltos del motor.

## Alcance del core

El core debe encargarse de:

- interceptacion
- validacion base
- sesion de voto
- logging
- API para terceros

El core no debe encargarse de:

- sanciones
- catalogos o flujos administrativos de sancion
- bans persistentes
- politicas administrativas especificas

## Estado del repo

Esta direccion ya se refleja en el proyecto:

- el core expone `sessionId`
- existe un contrato publico unico orientado a sesion
- `kicklimit` ya consume el core con identidad por `AccountID`
- el almacenamiento SQL ya usa columnas por `AccountID`

## Consecuencia de arquitectura

`callvote_bans` deja de marcar la direccion del diseño. La suite principal se concentra en un core reutilizable y las sanciones pasan a una capa externa.
