# Mrsose QoA

Addon complementario para **TradeSkillMaster (backport 3.3.5a de Keoo)** en servidores privados de WotLK.

## ¿Para qué sirve?

TSM en 3.3.5a tiene varios bugs conocidos (algunos por diferencias del emulador, otros por conflictos con otros addons). Este addon **no modifica ningún archivo de TSM** — en vez de eso, se engancha a las tablas internas de TSM en tiempo real (a través de `_G.TSMAddon`, que TSM expone él mismo) y reemplaza las funciones rotas desde afuera.

**Ventaja principal:** como no toca los archivos de TSM, estos arreglos **sobreviven a las actualizaciones del addon**. Puedes actualizar TSM sin perder los fixes (mientras Keoo no renombre las funciones/módulos parcheados aquí).

## Requisitos

- `TradeSkillMaster` (backport 3.3.5a) instalado y activo.
- Opcionalmente `TradeSkillMaster_Mailing` (para el fix #4).
- Mrsose QoA debe estar **activado** en la lista de addons junto con TSM.

## Instalación

1. Descomprime la carpeta `Mrsose QoA` completa dentro de `Interface/AddOns/`.
2. Actívalo en la pantalla de selección de personaje junto con TSM.
3. Relog o reinicia el cliente.

No requiere configuración — todos los arreglos se aplican automáticamente al cargar.

---

## Arreglos incluidos

### 1. Ítems no se detectaban como desencantables (`/tsm destroy`)
**Problema:** `Item.IsClassDisenchantable` usaba una tabla `Enum.ItemClass` que otro addon (compatible con ClassicAPI) sobreescribía con valores incorrectos (`Armor=2` en vez de `4`, `Weapon=1` en vez de `2`, `Profession=nil` en vez de `19`). Como resultado, ningún arma o armadura se reconocía nunca como desencantable, sin importar tu skill de Encantamiento.

**Arreglo:** se reemplaza `Item.IsClassDisenchantable` con una versión que usa los valores reales de WoW, sin depender de esa tabla `Enum` potencialmente corrupta.

### 2. Bolsas fuera de la mochila no se escaneaban al iniciar sesión
**Problema:** al hacer login o `/reload`, el sistema interno de TSM que rastrea el contenido de las bolsas (`BagTracking`) frecuentemente solo detectaba la bolsa 0 (mochila) — las bolsas 1-4 quedaban invisibles hasta que algo más forzaba un re-escaneo completo (por ejemplo, abrir la ventana de una profesión). Esto explicaba por qué `/tsm destroy` (y otras funciones que dependen del contenido de las bolsas) parecían fallar "al azar" justo después de entrar al juego.

**Arreglo:** se llama a `BagTracking.RescanAllBags()` automáticamente unos segundos después de entrar al mundo, sin necesidad de ningún "ritual" manual.

### 3. Error de Lua al subir de nivel / cambiar de zona en grupo
**Problema:** otra librería compartida (`LibGroupTalents`, usada por varios addons para sincronizar talentos entre miembros del grupo) a veces intenta mandar un mensaje de addon-comm que supera el límite de 254 bytes del protocolo del juego. La copia de `ChatThrottleLib` que queda activa globalmente (puede venir de TSM o de otro addon) tiraba un error de Lua visible en pantalla en vez de simplemente fallar el envío.

**Arreglo:** se envuelve `ChatThrottleLib:SendAddonMessage` para que descarte silenciosamente los mensajes demasiado grandes en lugar de lanzar un error. No afecta el envío de mensajes normales, solo evita el spam de errores en pantalla.

### 4. Los correos vacíos no se borraban solos tras usar "Open Mail" en TSM
**Problema:** el módulo `TradeSkillMaster_Mailing` solo borra automáticamente un correo vacío si el servidor reporta la bandera `textCreated` como verdadera — bandera que en muchos servidores privados no se reporta de forma confiable para correos simples de ítems/oro. El resultado: los correos se vaciaban correctamente (ítems y oro sí llegaban a la mochila), pero se quedaban acumulados en la bandeja para siempre.

**Arreglo:** en vez de tocar el código interno de Mailing (que se perdería con cada actualización), se engancha el botón público "Open Mail" (`Open.StartOpening`) para que, después de que TSM termine de abrir los correos, se ejecute un barrido propio e independiente del buzón usando solo la API nativa de WoW (`GetInboxHeaderInfo`, `GetInboxItem`, `DeleteInboxItem`) que borra cualquier correo que realmente esté vacío (sin ítems ni oro), sin depender de banderas del servidor.

---

### 5. Error de Lua al abrir una profesión: `attempt to index global 'TradeSkillFrame' (a nil value)`
**Problema:** con TSM Crafting activo, la ventana nativa de profesión de Blizzard (`TradeSkillFrame`) nunca llega a crearse. Otros addons que asumen que esa ventana siempre existe —como el skin que `ElvUI_AddOnSkins` le aplica a AckisRecipeList— tiran un error de Lua al intentar leerla (`ackisRecipeList.lua`, línea 73-74) cada vez que abres una profesión.

**Arreglo:** ya que no se puede tocar el código de AckisRecipeList/ElvUI_AddOnSkins (no son parte de TSM), se crea un `TradeSkillFrame` vacío e inofensivo apenas entras al mundo si no existe uno real. Esto no restaura el skin de AckisRecipeList sobre esa ventana (no hay ventana real que skinear), pero evita el error.

## Limitaciones conocidas

Existe un bug menor (una condición de carrera donde el `itemLevel` de un ítem a veces tarda en cargar justo en el momento del escaneo, causando que TSM lo marque como "no destruible" para siempre en esa sesión) que **no se puede arreglar desde un addon externo**, porque vive dentro de una función completamente privada de TSM inalcanzable desde afuera. Es poco frecuente; si notas que un ítem específico no se detecta como destruible pese a cumplir los requisitos, un `/reload` normalmente lo soluciona.

## Soporte

Este addon fue creado a medida para arreglos puntuales encontrados en un servidor específico. Si TSM actualiza y renombra los módulos/funciones mencionadas arriba, los parches de Mrsose QoA simplemente no se aplicarán (fallan de forma silenciosa vía `pcall`), pero no deberían romper nada — en ese caso, avisar para actualizar Mrsose QoA.
