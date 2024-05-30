


# BUR (Bad Upscaling Replacer)





**Copyright © 2024 Jakob Wapenhensch: [LICENSE](other_file.md)**

# TL;DR
ReShade shader that enhances spatial upscaling in games offering resolution scaling but applying only basic bilinear or bicubic upscaling, such as Battlefield 4, Metro 2033 Redux, and Paladins. Not compatible with selecting a lower than native main resolution; Effective only with resolution scale and SSAA below 1.0x or general subsampling. Unnecessary for games with advanced upscaling like DLSS, FSR, or Temporal Super Sampling/Reconstruction.
Also allows for the execution of shader effects before the upscaling step.

## What it is
BUR is a [ReShade](reshade.me) shader is meant to do two things:

1. Replace bad spatial upscaling 
2. Allow to render other shaders before upscaling

IMPORTANT:
```
This does NOT work when setting a game to a lower when native Resolution, via the main resolution setting in a game,
as than ReShade can also only render at that lower resolution. 
```
```
Both of the above only make sense in cases were a resolution scale is available, 
but only basic bilinear or bicubic upsampling is applied by default.
Some games may "hide" this resolution scale behind other names like SSAA 0.5x. 
```
```
If a game already includes DLSS, FSR or even classic Temporal Superampling/Reconstruction, using this is pointless.
```
Examples for such games are:
- Battlefield 4
- Metro 2033 Redux
- Paladins

***If you know any more, please let me know so i can list them here.***

You could also just use this shader to test different upsampling methods vs native resolution.

## How it works
This shader consists of two techniques that both need to be active.
This results in a four stage pipeline looking like this:

1. BUR_1_Prepass    
    - This effect resamples the badly upscaled image using the same method 
    that was used by the game to upscale to you native screen res.


    - The result of this is a texture with the resolution your game was originally rendering at.
    - This result is mapped to the upper left corner of the main viewport.

    Notices:
    ```
    Matching the upscaling method used by the game natively is important for good results. 
    Most games use some form of bicubic scaling, so thats the default.
    ```
    ```
    Usually no shaders should run before this.
    Exception to this are shaders, that can't work with the remapped image in the top left,
    as they need to run at native resolution and need the content to match the resolution.
    Best Example: 
    Motion estimation shaders like mine and marty's.
    ```
    
2. Other Shaders
    - You can place other shaders in between these two techniques, 
    that need to run on a clean rasterized output before upscaling.
    - Most common examples of such shaders are antialiasing shaders like:
        - FXAA
        - SMAA
        - CMAA2

3. BUR_2_Upscaling
    - This effect takes the processed image from the upper left corner of the viewport
    and scales it back to the native screen resolution, using a upscaling method of your choice.
    - Currently available are:
        - Point / Nearest Neighbor 
            - Might be useful for **some** pixel art games.
        - Bilinear
            - Let's not talk about this.
        - Bicubic
            - Same / similar to what most of the applicable games will use.
            Useful if you only want to inject shaders before upscaling.
        - AMD FSR 1
            - Looks close to Bicubic, but preserves edges way better.
    Notices:
    ```
    If you are not going for a pixel art look, you'll have to give the BUR_2_Upscaling an antialiased input for good results. It doesn't really matter if you use the games AA or some ReShade AA shader.
    ```

4. Other Shaders
    - All other shaders can be used as usual after BUR_2_Upscaling


## How To use it
### Installation
- Install [ReShade](reshade.me)
- Place the BUR folder in your reshade-shaders\Shaders folder.
 
 
### Ingame Usage
- Set the **resolution scale** option of your game to any value below 100%.

- In the ReShade UI, place the two effects **BUR_1_Prepass** and **BUR_2_Upscaling**
as described in the section "**How it works**".

- Set both the **RATIO_WIDTH** and **RATIO_HEIGHT** variables to the **decimal** presentation
of the value you used for the ingame resolution scale.

- Select the **Resampling Method** that matches the game used for upscaling (Should be cubic)

- Finally select the **Spatial Upscaling Method** of your choice.


## What it **can't** do
- Upscale beyond your native res or make up any new detail.
- Do real temporal or spatial supersampling.

## Comparisons
- https://imgsli.com/MjY4NDA0
- https://imgsli.com/MjY4NDAz
- https://imgsli.com/MjY4MTQw
