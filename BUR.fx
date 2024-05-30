/**
 *           _______      _    _      _______  
 *          |  ____ \    | |  | |    |  ____ \ 
 *          | |    \ \   | |  | |    | |    \ \
 *          | |____/ /   | |  | |    | |____/ /
 *          |  ____ <    | |  | |    |  ____ < 
 *          | |    \ \   | |  | |    | |    \ \
 *          | |____/ /   | |__| |    | |     \ \
 *          |_______/     \____/     |_|      \_\
 *
 *
 *        B A D   U P S C A L I N G   R E P L A C E R
 *          
 * ==================================================================================================
 *
 *
 * https://imgsli.com/MjY4MTQw
 *      
 *                      L I C E N S E
 *
 * --------------------------------------------------------------------------------------------------
 *
 *              Copyright (C) 2024 Jakob Wapenhensch 
 *
 * This code is part of the BUR (Bad Upscaling Replacer) project.
 * BUR is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License. 
 * https://creativecommons.org/licenses/by-nc-sa/4.0/
 *
 * --------------------------------------------------------------------------------------------------
 *
 *                   CC BY-NC-SA 4.0 DEED
 *
 *                      You are free to:
 *
 * Share — copy and redistribute the material in any medium or format
 * Adapt — remix, transform, and build upon the material
 *
 * The licensor cannot revoke these freedoms as long as you follow the license terms.
 *
 *
 *                  Under the following terms:
 *
 * Attribution
 *      You must give appropriate credit, provide a link to the license, and indicate if changes were made. 
 *      You may do so in any reasonable manner, but not in any way that suggests the licensor endorses you or your use.
 *
 * NonCommercial 
 *      You may not use the material for commercial purposes.
 *
 * ShareAlike
 *      If you remix, transform, or build upon the material, 
 *      you must distribute your contributions under the same license as the original.
 *
 * No additional restrictions 
 *      You may not apply legal terms or technological measures that legally restrict others from doing anything the license permits.
 *
 *
 *                           Notices:
 *
 * You do not have to comply with the license for elements of the material in the public domain
 * or where your use is permitted by an applicable exception or limitation .
 *
 * No warranties are given. The license may not give you all of the permissions necessary for your intended use. 
 * For example, other rights such as publicity, privacy, or moral rights may limit how you use the material.
 *
 * --------------------------------------------------------------------------------------------------
 *
 *                          IMPORTANT!
 *
 * The above deed highlights only some of the key features and terms of the actual license. 
 * It is not a license and has no legal value. You should carefully review all of the terms 
 * and conditions of the actual license before using the licensed material.
 * Creative Commons is not a law firm and does not provide legal services. 
 * Distributing, displaying, or linking to this deed or the license that it summarizes does not create a lawyer-client or any other relationship.
 *
 * --------------------------------------------------------------------------------------------------
 *
 * Functions implementing FSR 1 (EASU and RCAS), which are based on work by the user "goingdigital" on shadertoy
 * and are licensed under the MIT Open License. https://opensource.org/license/mit
 *
 * ==================================================================================================
 *
 *                           CREDITS
 *
 * Reshade team, for their amazing work on the Reshade it self.
 *
 * AMD, for their FSR 1 algorithm.
 *
 * "goingdigital" from shadertoy, for his hlsl ports of the AMD EASU and RCAS ports (FSR 1)
 * I changed a few things, but the code is mostly stil his: https://www.shadertoy.com/view/stXSWB
 *
**/


//////////////
// INCLUDES //  
////////////// 

#include "ReShadeUI.fxh"
#include "ReShade.fxh"
#include "BUR_fsr1.fxh"


/////////////
// DEFINES //  
/////////////  

// RATIO_WIDTH and RATIO_HEIGHT define the scaling factors for the width and height of the image
// RATIO_WIDTH and RATIO_HEIGHT should be screen res / game render res
#ifndef RATIO_WIDTH
 #define RATIO_WIDTH 	  	0.5 // Default scaling factor for width is 0.5 (50%)
#endif

#ifndef RATIO_HEIGHT
 #define RATIO_HEIGHT 	  	0.5 // Default scaling factor for height is 0.5 (50%)		
#endif

// Undefine DONT_CHANGE_X and DONT_CHANGE_Y to ensure they are not already defined
#ifdef DONT_CHANGE_X
 #undef DONT_CHANGE_X 
#endif
#ifdef DONT_CHANGE_Y
 #undef DONT_CHANGE_Y 
#endif

// DONT_CHANGE_X and DONT_CHANGE_Y define the dimensions of the output image
#ifndef DONT_CHANGE_X
 #define DONT_CHANGE_X BUFFER_WIDTH * RATIO_WIDTH
#endif

#ifndef DONT_CHANGE_Y
 #define DONT_CHANGE_Y BUFFER_HEIGHT * RATIO_HEIGHT
#endif

// Convenience defines for the scaling factors and output resolution
#define RATIO float2(RATIO_WIDTH, RATIO_HEIGHT)
#define ORIGINAL_RES float2(DONT_CHANGE_X, DONT_CHANGE_Y)


////////
// UI //  
////////

uniform int UI_RESAMPLE_METHOD <
	ui_type = "combo";
    ui_label = "Resampling Method";
	ui_items = "Point\0Linear\0Cubic\0";
	ui_tooltip = "Select sample method used to resample the badly upscaled original image.\nThis should idealy match the method used by the game to upscale the image.";
    ui_category = "Resampling Method. ";
> = 2;

uniform int UI_SPATIAL_UPSCALER <
	ui_type = "combo";
    ui_label = "Spatial Upscaling Method";
	ui_items = "Point\0Linear\0Cubic\0EASU (FSR 1.0)\0";
	ui_tooltip = "Select the spatial upscaler to use.";
    ui_category = "Spatial Upscaling";
> = 3;

uniform int UI_POST_SHARP <
	ui_type = "combo";
    ui_label = "Post Sharpening Method";
	ui_items = "OFF\0RCAS (FSR 1.0)\0";
	ui_tooltip = "Select the post upscaler sharpening method to use after upscaling.";
    ui_category = "Post";
> = 1;

uniform float UI_POST_SHARP_STRENGTH < __UNIFORM_DRAG_FLOAT1
	ui_min = 0.0; ui_max = 1.0; ui_step = 0.1;
	ui_tooltip = "Sharpening strength";
	ui_label = "Set the amount of sharpening to apply to the image after upscaling.";
    ui_category = "Post";
> = 0.5;

uniform int framecount < source = "framecount"; >;


/////////////////////////
// TEXTURES & SAMPLERS //  
/////////////////////////

// Textures
texture2D texColorBuffer : COLOR;
texture2D lowRedBaseTex { Width = int(DONT_CHANGE_X); Height = int(DONT_CHANGE_Y); Format = RGBA8; };

// Samplers
sampler2D colorSamplerPoint { Texture = texColorBuffer; AddressU = BORDER; AddressV = BORDER; MipFilter = Point; MinFilter = Point; MagFilter = Point; };
sampler2D colorSamplerLinear { Texture = texColorBuffer; AddressU = BORDER; AddressV = BORDER; MipFilter = Linear; MinFilter = Linear; MagFilter = Linear; };

sampler2D lowResColorPointSampler { Texture = lowRedBaseTex; AddressU = BORDER; AddressV = BORDER; MipFilter = Point; MinFilter = Point; MagFilter = Point; };
sampler2D lowResColorLinearSampler { Texture = lowRedBaseTex; AddressU = BORDER; AddressV = BORDER; MipFilter = Linear; MinFilter = Linear; MagFilter = Linear; };


///////////////
// Functions //  
///////////////

/**
 * Sample a texture using bilinear interpolation.
 * @param source - Sampler2D to sample from. Needs to be a linear sampler
 * @param texcoord - Position to sample in uv space (0.0 - 1.0)
**/
float4 sampleBicubic(sampler2D source, float2 texcoord)
{
	// Calculate the size of the source texture
    float2 texSize = tex2Dsize(source);

    // Calculate the position to sample in the source texture
    float2 samplePos = texcoord * texSize;

    // Calculate the integer and fractional parts of the sample position
    float2 texPos1 = floor(samplePos - 0.5f) + 0.5f;
    float2 f = samplePos - texPos1;

    // Calculate the interpolation weights for the four cubic spline basis functions
    float2 w0 = f * (-0.5f + f * (1.0f - 0.5f * f));
    float2 w1 = 1.0f + f * f * (-2.5f + 1.5f * f);
    float2 w2 = f * (0.5f + f * (2.0f - 1.5f * f));
    float2 w3 = 1.0f - (w0 + w1 + w2);

    // Calculate weights for two intermediate values (used for more efficient sampling)
    float2 w12 = w1 + w2;
    float2 offset12 = w2 / w12;

    // Calculate the positions to sample for the eight texels involved in bicubic interpolation
    float2 texPos0 = texPos1 - 1;
    float2 texPos3 = texPos1 + 2;
    float2 texPos12 = texPos1 + offset12;

    // Normalize the texel positions to the [0, 1] range
    texPos0 /= texSize;
    texPos3 /= texSize;
    texPos12 /= texSize;

    // Initialize the result variable, for accumulating the weighted samples
    float4 result = 0.0f;

    // Perform bicubic interpolation by sampling the source texture linearly
    // with the calculated weights at the calculated positions
    result += tex2Dlod(source, float4(texPos0.x, texPos0.y, 0, 0)) * w0.x * w0.y;
    result += tex2Dlod(source, float4(texPos12.x, texPos0.y, 0, 0)) * w12.x * w0.y;
    result += tex2Dlod(source, float4(texPos3.x, texPos0.y, 0, 0)) * w3.x * w0.y;

    result += tex2Dlod(source, float4(texPos0.x, texPos12.y, 0, 0)) * w0.x * w12.y;
    result += tex2Dlod(source, float4(texPos12.x, texPos12.y, 0, 0)) * w12.x * w12.y;
    result += tex2Dlod(source, float4(texPos3.x, texPos12.y, 0, 0)) * w3.x * w12.y;

    result += tex2Dlod(source, float4(texPos0.x, texPos3.y, 0, 0)) * w0.x * w3.y;
    result += tex2Dlod(source, float4(texPos12.x, texPos3.y, 0, 0)) * w12.x * w3.y;
    result += tex2Dlod(source, float4(texPos3.x, texPos3.y, 0, 0)) * w3.x * w3.y;

    return result;
}

/**
 * Sample a texture using FSR 1.0 upscaling.
 * @param source - Sampler2D to sample from. Needs to be a linear sampler
 * @param texcoord - Position to sample in uv space (0.0 - 1.0)
**/
float4 sampleFSR1(sampler2D source, float2 texcoord)
{
    float4 con0,con1,con2,con3;
    FsrEasuCon(con0, con1, con2, con3, ORIGINAL_RES, ORIGINAL_RES, ReShade::ScreenSize);
    float3 c = FsrEasuF(source, (texcoord * ReShade::ScreenSize) + (1.0 - RATIO), con0, con1, con2, con3);
    return float4(c.rgb, 1);
}



////////////
// Passes //  
////////////

//Retarget the content from the low res resampled texture to the top left corner of the native screen buffer.
float4 RetargetColor(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    // Divide texture coordinates by RATIO to get coordinates for upscaled image
    float2 coords = texcoord / RATIO;

    float4 color = 0;
    // Switch statement to select resampling method
    switch (UI_RESAMPLE_METHOD)
    {
     
        case 0:
            // Point sampling
            color = tex2Dlod(colorSamplerPoint, float4(coords,0,0));
            break;
        case 1:
            // Bilinear filtering
            color = tex2Dlod(colorSamplerLinear, float4(coords,0,0));
            break;
        case 2:
            // Bicubic filtering
            color = sampleBicubic(colorSamplerLinear, coords);
            break;
        default:
            // Default to point sampling if invalid method selected
            color = tex2Dlod(colorSamplerPoint, float4(coords,0,0));
            break;
    }
    // Return upscaled color
    return color;
}

//Save the content from the top left corner of the native screen buffer to a texture of the size of that area.
float4 SaveLowResPostFX(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float2 coords = texcoord * ReShade::ScreenSize * RATIO;
    return tex2Dfetch(colorSamplerPoint, int2(coords));
}

//Upscale the content of the low res texture to the native screen buffer.
float4 UpscalingMain(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float4 color = 0;
    switch (UI_SPATIAL_UPSCALER)
    {
        case 0:
            color = tex2Dlod(lowResColorPointSampler, float4(texcoord,0,0));
            break;
        case 1:
            color = tex2Dlod(lowResColorLinearSampler, float4(texcoord,0,0));
            break;
        case 2:
            color = sampleBicubic(lowResColorLinearSampler, texcoord);
            break;
        case 3:
            color = sampleFSR1(lowResColorLinearSampler, texcoord);
            break;
        default:
            color = tex2Dlod(lowResColorPointSampler, float4(texcoord,0,0));
            break;
    }

    return color;
}



//Apply post processing effects to the upscaled content.
float4 UpscalingPost(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float4 color = 0;
    switch (UI_POST_SHARP)
    {
        case 1:
            float base = 8;
            float sharpeness = ((base + 0.1) - (sqrt(sqrt(UI_POST_SHARP_STRENGTH)) * base)) * RATIO;
            color = Rcas(colorSamplerLinear, texcoord, sharpeness);
            break;
        default:
            color = tex2Dlod(colorSamplerPoint, float4(texcoord,0,0));
            break;
    }

    return color;
}


////////////////
// Techniques //  
////////////////


technique BUR_1_Prepass < ui_tooltip = "This is an example!"; >
{
    pass P1_Resample
    {
        VertexShader = PostProcessVS;
        PixelShader = RetargetColor;
    }
}

technique BUR_2_Upscaling < ui_tooltip = "This is an example!"; >
{
    pass P2_save_low_res
    {
        VertexShader = PostProcessVS;
        PixelShader = SaveLowResPostFX;
        RenderTarget = lowRedBaseTex;
    }

    pass P3_upsampling_main
    {
        VertexShader = PostProcessVS;
        PixelShader = UpscalingMain;
    }    
  
    pass P4_upsampling_post
    {
        VertexShader = PostProcessVS;
        PixelShader = UpscalingPost;
    }
}