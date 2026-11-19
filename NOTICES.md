# Avisos de terceros

El código y los aportes originales de lechuga, incluidos sus `.sp` e `.inc` propios, se distribuyen bajo `GPL-3.0-only`. El texto completo está en [LICENSE](LICENSE). Las siguientes atribuciones y condiciones corresponden al material incorporado o utilizado al compilar. Las rutas de los includes son relativas a `addons/sourcemod/scripting/include/`.

- `colors.inc` conserva el crédito de Colored Chat Functions para exvel, Popoklopsi, Powerlord y Bara. La licencia de la copia usada en este proyecto queda pendiente de verificar.
- `callvote_core.inc` conserva el aviso GPL v3, el crédito de AlliedModders y la excepción de enlace de su cabecera. `l4d2_commcore.inc` es una interfaz de [L4D2-CommSuite](https://github.com/AoC-Gamers/L4D2-CommSuite).
- `left4dhooks*.inc` conserva los créditos de Left 4 DHooks Direct y sus predecesores. Las cabeceras indican qué archivos usan GPL v3 o posterior y cuáles declaran GPL v3 con excepción de enlace.
- `confogl.inc` corresponde al Confogl Team. Su cabecera declara GPL v3 y contiene la excepción de enlace con Source Engine y sus mods.
- `localizer.inc` conserva el aviso GPL v3 o posterior y el copyright de Stanislav «Dragokas» Polshyn según su cabecera.
- `builtinvotes.inc` y `builtinvotes_stocks.inc` conservan los avisos GPL v3 y las excepciones de enlace de sus cabeceras.
- `system2/legacy.inc` y `system2/request.inc` conservan los avisos GPL v3 o posterior y la autoría de David Ordnung.
- `steamidtools.inc` y `steamidtools/` son copias de SteamIDTools. El proyecto de origen ofrece su código propio bajo GPL v3 o posterior. Se conservan los avisos de los includes distribuidos. [SteamIDTools](https://github.com/AoC-Gamers/SteamIDTools#licencia)
- `campaign_manager.inc` y `language_manager.inc` conservan su atribución a lechuga como bibliotecas compartidas.

## Aviso del SDK de SourceMod

```text
SOURCEMOD LICENSE INFORMATION
VERSION: 2019-9-30
-----------------------------

SourceMod is licensed under the GNU General Public License, version 3.  

As a special exception, AlliedModders LLC gives you permission to link the code
of this program (as well as its derivative works) to "Half-Life 2," the "Source 
Engine" and any Game MODs that run on software by the Valve Corporation.
You must obey the GNU General Public License in all respects for all other code used.
Additionally, AlliedModders LLC grants this exception to all derivative works.

As an additional special exception to the GNU General Public License 3.0, 
AlliedModders LLC permits dual-licensing of DERIVATIVE WORKS ONLY (that is, 
SourcePawn/SourceMod Plugins and SourceMod Extensions, or any software built 
from the SourceMod SDK or header files) under the GNU General Public License 
version 2 "or any higher version."  As such, you may choose for your derivative 
work(s) to be compatible with the GNU General Public License version 2 as long 
as it is also compatible with the GNU General Public License version 3, via the 
"or any higher version" clause.  This is intended for compatibility with other
software.

As a final exception to the above, any derivative works created prior to this 
date (July 31, 2007) may be exclusively licensed under the GNU General Public 
License version 2 (without an "or any higher version" clause) if and only if 
the work was already GNU General Public License 2.0 exclusive.  This clause is 
provided for backwards compatibility only.

A copy of the GNU General Public License 2.0 is available in GPLv2.txt.
A copy of the GNU General Public License 3.0 is available in GPLv3.txt.

SourcePawn is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
SourceMod is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
Pawn and SMALL are Copyright (C) 1997-2008 ITB CompuPhase.
Source is Copyright (C) Valve Corporation.
All trademarks are property of their respective owners in the US and other countries.
```

## Avisos reproducidos de los includes

### `builtinvotes.inc`

```text
/**
 * vim: set ts=4 :
 * =============================================================================
 * BuiltinVotes (C)2011 Ross Bemrose (Powerlord).  All rights reserved.
 * =============================================================================
 *
 * This file is part of the BuiltinVotes addon.
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: $Id$
 */
```

### `builtinvotes_stocks.inc`

```text
/**
 * vim: set ts=4 :
 * =============================================================================
 * BuiltinVotes (C)2011 Ross Bemrose (Powerlord).  All rights reserved.
 * =============================================================================
 *
 * This file is part of the BuiltinVotes addon.
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2,"
 * the "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: $Id$
 */
```

### `confogl.inc`

```text
/* *
 * =============================================================================
 * Confogl.inc
 * Confogl (C)2011 Confogl Team
 * =============================================================================
 *
 * This file is part of the Confogl competitive L4D2 plugin suite.
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, Confogl Team gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, Confogl Team grants
 * this exception to all derivative works. Confogl defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 */
```

### `left4dhooks.inc`

```text
/**
 * vim  set ts=4
 * =============================================================================
 *
 * Left 4 Downtown 2 SourceMod Extension
 * Copyright (C) 2010 Michael "ProdigySim" Busby
 *
 * Left 4 Downtown SourceMod Extension
 * Copyright (C) 2009 Igor "Downtown1" Smirnov
 *
 * Left 4 Downtown 2 Extension updates
 * Copyright (C) 2012-2015 "Visor"
 *
 * Left 4 Downtown 2 Extension updates
 * Copyright (C) 2015 "Attano"
 *
 * Left 4 Downtown 2 Extension updates
 * Copyright (C) 2017 "Accelerator74"
 *
 * Left 4 DHooks Direct SourceMod plugin
 * Copyright (C) 2026 "SilverShot" / "Silvers"
 *
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http //www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http //www.sourcemod.net/license.php>.
 *
 * Version  $Id$
 */
```

### `left4dhooks_anim.inc`

```text
/*
*	Left 4 DHooks Direct
*	Copyright (C) 2026 Silvers
*
*	This program is free software: you can redistribute it and/or modify
*	it under the terms of the GNU General Public License as published by
*	the Free Software Foundation, either version 3 of the License, or
*	(at your option) any later version.
*
*	This program is distributed in the hope that it will be useful,
*	but WITHOUT ANY WARRANTY; without even the implied warranty of
*	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*	GNU General Public License for more details.
*
*	You should have received a copy of the GNU General Public License
*	along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/
```

### `left4dhooks_lux_library.inc`

```text
/**
* Copyright (C) 2026 LuxLuma
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <https://www.gnu.org/licenses/>.
**/
```

### `left4dhooks_silver.inc`

```text
/*
*	Left 4 DHooks Direct - Stock Functions
*	Copyright (C) 2026 Silvers
*
*	This program is free software: you can redistribute it and/or modify
*	it under the terms of the GNU General Public License as published by
*	the Free Software Foundation, either version 3 of the License, or
*	(at your option) any later version.
*
*	This program is distributed in the hope that it will be useful,
*	but WITHOUT ANY WARRANTY; without even the implied warranty of
*	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*	GNU General Public License for more details.
*
*	You should have received a copy of the GNU General Public License
*	along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/
```

### `left4dhooks_stocks.inc`

```text
/**
 * =============================================================================
 * Left 4 Dead Stocks Library (C)2011-2012 Buster "Mr. Zero" Nielsen
 * Syntax Update and merge into "Left 4 DHooks Direct" (C) 2026 "SilverShot"
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License, version 3.0, as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2,"
 * the "Source Engine," the "SourcePawn JIT," and any Game MODs that run on
 * software by the Valve Corporation.  You must obey the GNU General Public
 * License in all respects for all other code used.  Additionally,
 * AlliedModders LLC grants this exception to all derivative works.
 * AlliedModders LLC defines further exceptions, found in LICENSE.txt
 * (as of this writing, version JULY-31-2007), or
 * <http://www.sourcemod.net/license.php>.
 */
```

### `localizer.inc`

```text
/**
 * Localizer.inc | API | Using instrinsic in-game translation #phrases
 *
 * Copyright (C) 2022 Stanislav "Dragokas" Polshyn
 *
 * This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
 **/
```

### `system2/legacy.inc`

```text
/**
 * -----------------------------------------------------
 * File        legacy.inc
 * Authors     David Ordnung
 * License     GPLv3
 * Web         http://dordnung.de
 * -----------------------------------------------------
 *
 * Copyright (C) 2013-2020 David Ordnung
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>
 */
```

### `system2/request.inc`

```text
/**
 * -----------------------------------------------------
 * File        request.inc
 * Authors     David Ordnung
 * License     GPLv3
 * Web         http://dordnung.de
 * -----------------------------------------------------
 *
 * Copyright (C) 2013-2020 David Ordnung
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>
 */
```
