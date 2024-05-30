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
 *                      L I C E N S E
 *
 * --------------------------------------------------------------------------------------------------
 *
 *              Copyright © 2024 Jakob Wapenhensch 
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
 * "goingdigital" from shadertoy, for his hlsl ports of the AMD EASU and RCAS (FSR 1)
 * I changed a few things, but the code is mostly stil his: https://www.shadertoy.com/view/stXSWB
 *
**/


/***** RCAS Settings*****/
#define FSR_RCAS_LIMIT (0.25-(1.0/16.0))


/**** EASU ****/

// 
void FsrEasuCon(
    out float4 con0,
    out float4 con1,
    out float4 con2,
    out float4 con3,
    // This the rendered image resolution being upscaled
    float2 inputViewportInPixels,
    // This is the resolution of the resource containing the input image (useful for dynamic resolution)
    float2 inputSizeInPixels,
    // This is the display resolution which the input image gets upscaled to
    float2 outputSizeInPixels
)
{
    // Output integer position to a pixel position in viewport.
    con0 = float4(
        float2(inputViewportInPixels / outputSizeInPixels),
        float2(0.5 * inputViewportInPixels / outputSizeInPixels - 0.5) - 0.5
    );
    // Viewport pixel position to normalized image space.
    // This is used to get upper-left of 'F' tap.
    con1 = float4(1, 1, 1, -1) / inputSizeInPixels.xyxy;
    // Centers of gather4, first offset from upper-left of 'F'.
    //      +---+---+
    //      |   |   |
    //      +--(0)--+
    //      | b | c |
    //  +---F---+---+---+
    //  | e | f | g | h |
    //  +--(1)--+--(2)--+
    //  | i | j | k | l |
    //  +---+---+---+---+
    //      | n | o |
    //      +--(3)--+
    //      |   |   |
    //      +---+---+
    // These are from (0) instead of 'F'.
    con2 = float4(-1, 2, 1, 2) / inputSizeInPixels.xyxy;
    con3 = float4(0, 4, 0,0) / inputSizeInPixels.xyxy;
}

// Filtering for a given tap for the scalar.
void FsrEasuTapF(
    inout float3 aC, // Accumulated color, with negative lobe.
    inout float aW, // Accumulated weight.
    float2 off, // Pixel offset from resolve position to tap.
    float2 dir, // Gradient direction.
    float2 len, // Length.
    float lob, // Negative lobe strength.
    float clp, // Clipping point.
    float3 c
)
{
    // Tap color.
    // Rotate offset by direction.
    float2 v = float2(dot(off, dir), dot(off,float2(-dir.y, dir.x)));
    // Anisotropy.
    v *= len;
    // Compute distance^2.
    float d2 = min(dot(v, v), clp);
    // Limit to the window as at corner, 2 taps can easily be outside.
    // Approximation of lancos2 without sin() or rcp(), or sqrt() to get x.
    //  (25/16 * (2/5 * x^2 - 1)^2 - (25/16 - 1)) * (1/4 * x^2 - 1)^2
    //  |_______________________________________|   |_______________|
    //                   base                             window
    // The general form of the 'base' is,
    //  (a*(b*x^2-1)^2-(a-1))
    // Where 'a=1/(2*b-b^2)' and 'b' moves around the negative lobe.
    float wB = .4 * d2 - 1.0;
    float wA = lob * d2 -1.0;
    wB *= wB;
    wA *= wA;
    wB = 1.5625 * wB - 0.5625;
    float w=  wB * wA;
    // Do weighted average.
    aC += c*w;
    aW += w;
}

//------------------------------------------------------------------------------------------------------------------------------
// Accumulate direction and length.
void FsrEasuSetF(
    inout float2 dir,
    inout float len,
    float w,
    float lA, float lB, float lC, float lD, float lE
)
{
    // Direction is the '+' diff.
    //    a
    //  b c d
    //    e
    // Then takes magnitude from abs average of both sides of 'c'.
    // Length converts gradient reversal to 0, smoothly to non-reversal at 1, shaped, then adding horz and vert terms.
    float lenX = max(abs(lD - lC), abs(lC - lB));
    float dirX = lD - lB;
    dir.x += dirX * w;
    lenX = clamp(abs(dirX) / lenX, 0.0 , 1.0);
    lenX *= lenX;
    len += lenX * w;
    // Repeat for the y axis.
    float lenY = max(abs(lE - lC), abs(lC - lA));
    float dirY = lE - lA;
    dir.y += dirY * w;
    lenY = clamp(abs(dirY) / lenY, 0.0, 1.0);
    lenY *= lenY;
    len += lenY * w;
}

float3 FsrEasuF(
    sampler2D samp,
    float2 pixelcoords, // Integer pixel position in output.
    float4 con0, 
    float4 con1,
    float4 con2,
    float4 con3
)
{
    // Get position of 'f'.
    float2 pp = pixelcoords * con0.xy + con0.zw; // Corresponding input pixel/subpixel
    float2 fp = floor(pp);// fp = source nearest pixel
    pp -= fp; // pp = source subpixel

    // 12-tap kernel.
    //    b c
    //  e f g h
    //  i j k l
    //    n o
    // Gather 4 ordering.
    //  a b
    //  r g
    float2 p0 = fp * con1.xy + con1.zw;
    
    // These are from p0 to avoid pulling two constants on pre-Navi hardware.
    float2 p1 = p0 + con2.xy;
    float2 p2 = p0 + con2.zw;
    float2 p3 = p0 + con3.xy;

    float4 off = float4(-.5,.5,-.5,.5) * con1.xxyy;

    // x=west y=east z=north w=south
    float3 bC = tex2Dlod(samp, float4(p0 + off.xw, 0, 0)).rgb; float bL = bC.g + 0.5 * (bC.r + bC.b);
    float3 cC = tex2Dlod(samp, float4(p0 + off.yw, 0, 0)).rgb; float cL = cC.g + 0.5 * (cC.r + cC.b);
    float3 iC = tex2Dlod(samp, float4(p1 + off.xw, 0, 0)).rgb; float iL = iC.g + 0.5 * (iC.r + iC.b);
    float3 jC = tex2Dlod(samp, float4(p1 + off.yw, 0, 0)).rgb; float jL = jC.g + 0.5 * (jC.r + jC.b);
    float3 fC = tex2Dlod(samp, float4(p1 + off.yz, 0, 0)).rgb; float fL = fC.g + 0.5 * (fC.r + fC.b);
    float3 eC = tex2Dlod(samp, float4(p1 + off.xz, 0, 0)).rgb; float eL = eC.g + 0.5 * (eC.r + eC.b);
    float3 kC = tex2Dlod(samp, float4(p2 + off.xw, 0, 0)).rgb; float kL = kC.g + 0.5 * (kC.r + kC.b);
    float3 lC = tex2Dlod(samp, float4(p2 + off.yw, 0, 0)).rgb; float lL = lC.g + 0.5 * (lC.r + lC.b);
    float3 hC = tex2Dlod(samp, float4(p2 + off.yz, 0, 0)).rgb; float hL = hC.g + 0.5 * (hC.r + hC.b);
    float3 gC = tex2Dlod(samp, float4(p2 + off.xz, 0, 0)).rgb; float gL = gC.g + 0.5 * (gC.r + gC.b);
    float3 oC = tex2Dlod(samp, float4(p3 + off.yz, 0, 0)).rgb; float oL = oC.g + 0.5 * (oC.r + oC.b);
    float3 nC = tex2Dlod(samp, float4(p3 + off.xz, 0, 0)).rgb; float nL = nC.g + 0.5 * (nC.r + nC.b);
   
    // Simplest multi-channel approximate luma possible (luma times 2, in 2 FMA/MAD).
    // Accumulate for bilinear interpolation.
    float2 dir = 0;
    float len = 0.;

    FsrEasuSetF(dir, len, (1.0 - pp.x) * (1.0 - pp.y), bL, eL, fL, gL, jL);
    FsrEasuSetF(dir, len, pp.x * (1.0 - pp.y), cL, fL, gL, hL, kL);
    FsrEasuSetF(dir, len, (1.0 - pp.x) * pp.y, fL, iL, jL, kL, nL);
    FsrEasuSetF(dir, len, pp.x * pp.y, gL, jL, kL, lL, oL);

    // Normalize with approximation, and cleanup close to zero.
    float2 dir2 = dir * dir;
    float dirR = dir2.x + dir2.y;
    bool zro = dirR < (1.0 / 32768.0);
    dirR = rsqrt(dirR);
    dirR = zro ? 1.0 : dirR;
    dir.x = zro ? 1.0 : dir.x;
    dir *= float2(dirR, dirR);

    // Transform from {0 to 2} to {0 to 1} range, and shape with square.
    len = len * 0.5;
    len *= len;

    // Stretch kernel {1.0 vert|horz, to sqrt(2.0) on diagonal}.
    float stretch = dot(dir,dir) / (max(abs(dir.x), abs(dir.y)));

    // Anisotropic length after rotation,
    //  x := 1.0 lerp to 'stretch' on edges
    //  y := 1.0 lerp to 2x on edges
    float2 len2 = float2(1.0 + (stretch - 1.0) * len, 1.0 - 0.5 * len);

    // Based on the amount of 'edge',
    // the window shifts from +/-{sqrt(2.0) to slightly beyond 2.0}.
    float lob = 0.5 - 0.29 * len;

    // Set distance^2 clipping point to the end of the adjustable window.
    float clp = 1.0 / lob;

    // Accumulation mixed with min/max of 4 nearest.
    //    b c
    //  e f g h
    //  i j k l
    //    n o
    float3 min4 = min(min(fC, gC), min(jC, kC));
    float3 max4 = max(max(fC, gC), max(jC, kC));
    // Accumulation.
    float3 aC = 0;
    float aW = 0.;
    FsrEasuTapF(aC, aW, float2( 0,-1) - pp, dir, len2, lob, clp, bC);
    FsrEasuTapF(aC, aW, float2( 1,-1) - pp, dir, len2, lob, clp, cC);
    FsrEasuTapF(aC, aW, float2(-1, 1) - pp, dir, len2, lob, clp, iC);
    FsrEasuTapF(aC, aW, float2( 0, 1) - pp, dir, len2, lob, clp, jC);
    FsrEasuTapF(aC, aW, float2( 0, 0) - pp, dir, len2, lob, clp, fC);
    FsrEasuTapF(aC, aW, float2(-1, 0) - pp, dir, len2, lob, clp, eC);
    FsrEasuTapF(aC, aW, float2( 1, 1) - pp, dir, len2, lob, clp, kC);
    FsrEasuTapF(aC, aW, float2( 2, 1) - pp, dir, len2, lob, clp, lC);
    FsrEasuTapF(aC, aW, float2( 2, 0) - pp, dir, len2, lob, clp, hC);
    FsrEasuTapF(aC, aW, float2( 1, 0) - pp, dir, len2, lob, clp, gC);
    FsrEasuTapF(aC, aW, float2( 1, 2) - pp, dir, len2, lob, clp, oC);
    FsrEasuTapF(aC, aW, float2( 0, 2) - pp, dir, len2, lob, clp, nC);

    // Normalize and dering.
    return min(max4, max(min4, aC / aW));
}



/***** RCAS *****/
// Input callback prototypes that need to be implemented by calling shader
float4 FsrRcasLoadF(sampler2D samp, float2 p) {
    return tex2Dlod(samp, float4(p * ReShade::PixelSize, 0, 0));
}

float FsrRcasCon(float sharpness)
{
    // Transform from stops to linear value.
    return exp2(-sharpness);
}

float3 FsrRcasF(
    sampler2D samp, float2 ip, float con
)
{
    // Constant generated by RcasSetup().
    // Algorithm uses minimal 3x3 pixel neighborhood.
    //    b 
    //  d e f
    //    h
    float3 b = FsrRcasLoadF(samp, ip + float2( 0,-1)).rgb;
    float3 d = FsrRcasLoadF(samp, ip + float2(-1, 0)).rgb;
    float3 e = FsrRcasLoadF(samp, ip).rgb;
    float3 f = FsrRcasLoadF(samp, ip + float2( 1, 0)).rgb;
    float3 h = FsrRcasLoadF(samp, ip + float2( 0, 1)).rgb;

    // Luma times 2.
    float bL = b.g + 0.5 * (b.b + b.r);
    float dL = d.g + 0.5 * (d.b + d.r);
    float eL = e.g + 0.5 * (e.b + e.r);
    float fL = f.g + 0.5 * (f.b + f.r);
    float hL = h.g + 0.5 * (h.b + h.r);

    // Noise detection.
    float nz = 0.25 * (bL + dL + fL + hL) - eL;
    nz=clamp(
        abs(nz) / (
             max(max(bL, dL), max(eL, max(fL, hL)))
            -min(min(bL, dL), min(eL, min(fL, hL)))
        ),
        0.,
        1.
    );
    nz=1.0 - 0.5 * nz;
    // Min and max of ring.
    float3 mn4 = min(b, min(f, h));
    float3 mx4 = max(b, max(f, h));

    // Immediate constants for peak range.
    float2 peakC = float2(1.0, -4.0);

    // Limiters, these need to be high precision RCPs.
    float3 hitMin = mn4 / (4.0 * mx4);
    float3 hitMax = (peakC.x - mx4) / (4.0 * mn4 + peakC.y);
    float3 lobeRGB = max(-hitMin, hitMax);
    float lobe = max(
        -FSR_RCAS_LIMIT,
        min(max(lobeRGB.r, max(lobeRGB.g, lobeRGB.b)), 0.0)
    )*con;

    // Apply noise removal.
    lobe *= nz;

    // Resolve, which needs the medium precision rcp approximation to avoid visible tonality changes.
    return (lobe * (b + d + h + f) + e) / (4. * lobe + 1.);
} 


float4 Rcas(sampler2D samp, float2 texcoord, float sharpness)
{
    // Calculate the fragment coordinates from the texture coordinates
    float2 fragCoord = texcoord * tex2Dsize(samp);

    // Calculate the contrast value based on the sharpness
    float con = FsrRcasCon(sharpness);
    
    // Apply the RCAS sharpening filter
    float3 col = FsrRcasF(samp, fragCoord, con);
    
    // Return the sharpened color with an alpha of 1.0
    return float4(col, 0);
}

