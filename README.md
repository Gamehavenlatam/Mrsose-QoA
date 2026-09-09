# Mrsose QoA — TSM (3.3.5a) Community Fixes

Colección de arreglos para **TradeSkillMaster** (backport 3.3.5a de Keoo) en servidores privados de WotLK, encontrados y documentados jugando en un server 3.3.5a real.

## Contenido de este repo

```
.
├── Mrsose QoA/          Addon complementario — instálalo y listo, sin tocar TSM
│   ├── Mrsose QoA.toc
│   ├── Mrsose QoA.lua
│   └── README.md        Detalle de cada arreglo que trae este addon
└── docs/                 Reportes de bugs para el dev de TSM (Keoo), en inglés y ruso
    ├── TSM_Destroying_Bug_Report.md
    └── TSM_Crafting_Refresh_Bug_Report.md
```

## ¿Qué es "Mrsose QoA"?

Un addon pequeño e independiente que **no modifica ningún archivo de TSM**. En vez de eso, se engancha en caliente a las tablas internas que TSM expone (`_G.TSMAddon`) y corrige ahí las funciones rotas. Como no toca los archivos de TSM en disco, estos arreglos **sobreviven a las actualizaciones del addon**.

Ver [`Mrsose QoA/README.md`](./Mrsose%20QoA/README.md) para el detalle completo de cada bug y su arreglo. Resumen rápido:

1. Ítems de armadura/armas no se detectaban como desencantables (`/tsm destroy`) — tabla `Enum.ItemClass` corrupta por otro addon.
2. Bolsas fuera de la mochila no se escaneaban al iniciar sesión (`BagTracking`).
3. Error de Lua al subir de nivel/cambiar de zona en grupo (`ChatThrottleLib` + `LibGroupTalents`).
4. Correos vacíos no se borraban solos tras "Open Mail" en TSM Mailing.
5. Error de Lua al abrir una profesión (`TradeSkillFrame` nil) por conflicto con AckisRecipeList/ElvUI_AddOnSkins.

## Instalación

1. Descarga/clona este repo.
2. Copia la carpeta `Mrsose QoA` completa a `Interface/AddOns/`.
3. Actívalo en la pantalla de selección de personaje junto con `TradeSkillMaster`.
4. Relog o reinicia el cliente. No requiere configuración.

## Sobre `docs/`

Dos bugs adicionales, más profundos, requerían tocar directamente archivos internos de TSM (funciones completamente privadas, inalcanzables desde un addon externo). Esos NO están parcheados por "Mrsose QoA" — en cambio, `docs/` contiene el reporte técnico completo (causa raíz + diff del arreglo, en inglés y ruso) listo para mandarle al desarrollador de TSM (Keoo) para que lo integre en una futura versión oficial:

- **Destroying**: el bug de `/tsm destroy` no detectando nada hasta abrir la ventana de encantamiento.
- **Crafting**: nivel de profesión y cantidad craftable que no se actualizan hasta cerrar y reabrir la ventana.

Ambos comparten en parte la misma causa raíz: el sistema `BagTracking` de TSM no es confiable con bolsas fuera de la mochila (bag 0) en este backport de 3.3.5a.

## Limitaciones conocidas

- Un bug menor de condición de carrera con `itemLevel` en Destroying no se puede arreglar desde un addon externo (ver detalle en `Mrsose QoA/README.md`).
- Si Keoo actualiza TSM y renombra los módulos/funciones que "Mrsose QoA" parchea, esos parches simplemente dejan de aplicarse (fallan en silencio vía `pcall`) sin romper nada — en ese caso, hay que actualizar este addon.

## Créditos

Encontrado, diagnosticado y parcheado por Mrsose.
