module WebGL where

{-| The WebGL API is for high performance rendering. Definitely read about
[how WebGL works](https://github.com/johnpmayer/elm-webgl/blob/master/README.md)
and look at some examples before trying to do too much with just the
documentation provided here.

# Main Types
@docs Texture, TextureFilter, Shader, Renderable, Error, Drawable

# Entities
@docs render, renderWithConfig

# WebGL Element
@docs webgl, webglWithConfig, defaultConfiguration

# WebGL API Calls
@docs FunctionCall

# WebGL API Types
@docs Capability, BlendOperation, BlendMode, CompareMode, FaceMode, ZMode

# Loading Textures
@docs loadTexture, loadTextureWithFilter, textureSize

# Unsafe Shader Creation (for library writers)
@docs unsafeShader

# Functions
@docs computeAPICall, computeAPICalls, computeBlendModeString, computeBlendOperationString, computeCapabilityString, computeCompareModeString, computeFaceModeString, computeZModeString

-}

import Graphics.Element exposing (Element)
import Native.WebGL
import Task exposing (Task)

{-| 
WebGl has a number of rendering modes available. Each of the tagged union types 
maps to a separate rendering mode. 

Triangles are the basic building blocks of a mesh. You can put them together
to form any shape. Each corner of a triangle is called a *vertex* and contains a
bunch of *attributes* that describe that particular corner. These attributes can
be things like position and color.

So when you create a `Triangle` you are really providing three sets of attributes
that describe the corners of a triangle.

See: [Library reference](https://msdn.microsoft.com/en-us/library/dn302395(v=vs.85).aspx) for the description of each type. 
-}

type Drawable attributes
  = Triangle (List (attributes, attributes, attributes))
  | Lines (List (attributes, attributes) )
  | LineStrip (List attributes)
  | LineLoop (List attributes)
  | Points (List attributes)
  | TriangleFan (List attributes)
  | TriangleStrip (List attributes)

{-| Shader is a phantom data type. Don't instantiate it yourself. See below.
-}
type Shader attributes uniforms varyings = Shader


{-| Shaders are programs for running many computations on the GPU in parallel.
They are written in a language called
[GLSL](http://en.wikipedia.org/wiki/OpenGL_Shading_Language). Read more about
shaders [here](https://github.com/johnpmayer/elm-webgl/blob/master/README.md).

Normally you specify a shader with a `shader` block. This is because shaders
must be compiled before they are used, imposing an overhead that it is best to
avoid in general. This function lets you create a shader with a raw string of
GLSL. It is intended specifically for libary writers who want to create shader
combinators.
-}
unsafeShader : String -> Shader attribute uniform varying
unsafeShader =
  Native.WebGL.unsafeCoerceGLSL

{-| A `Texture` loads a texture with linear filtering enabled. If you do not
want filtering, create a `RawTexture` with `loadTextureRaw`.
-}
type Texture = Texture

{-| Textures work in two ways when looking up a pixel value - Linear or Nearest 
-}
type TextureFilter = Linear | Nearest

{-| An error which occured in the graphics ocntext -}
type Error = Error

{-| Loads a texture from the given url. PNG and JPEG are known to work, but
other formats have not been as well-tested yet.
-}
loadTexture : String -> Task Error Texture
loadTexture = loadTextureWithFilter Linear 

{-| Loads a texture from the given url. PNG and JPEG are known to work, but
other formats have not been as well-tested yet. Configurable filter.
-}
loadTextureWithFilter : TextureFilter -> String -> Task Error Texture
loadTextureWithFilter filter url = Native.WebGL.loadTextureRaw Linear url

{-| Return the (width, height) size of a texture. Useful for sprite sheets
or other times you may want to use only a potion of a texture image.
-}
textureSize : Texture -> (Int, Int)
textureSize =
    Native.WebGL.textureSize

{-| Conceptually, an encapsulataion of the instructions to render something -}
type Renderable = Renderable 

{-| Packages a vertex shader, a fragment shader, a mesh, and uniform variables
as an `Renderable`. This specifies a full rendering pipeline to be run on the GPU.
You can read more about the pipeline
[here](https://github.com/johnpmayer/elm-webgl/blob/master/README.md).

Values will be cached intelligently, so if you have already sent a shader or
mesh to the GPU, it will not be resent. This means it is fairly cheap to create
new entities if you are reusing shaders and meshes that have been used before.
-}
renderWithConfig : List FunctionCall -> Shader attributes uniforms varyings -> Shader {} uniforms varyings -> (Drawable attributes) -> uniforms -> Renderable
renderWithConfig functionCalls vert frag buffer uniforms =
  computeAPICalls functionCalls
  |> Native.WebGL.render vert frag buffer uniforms


{-| Same as `renderWithConfig` but without using
custom per-render configurations.
-}
render : Shader attributes uniforms varyings -> Shader {} uniforms varyings -> (Drawable attributes) -> uniforms -> Renderable
render = renderWithConfig []


{-| Default configuration that is used as
the implicit configurations for `webgl`.
-}
defaultConfiguration : List FunctionCall
defaultConfiguration =
  [ Enable DepthTest
  ]


{-| Same as webglWithConfig but with default configurations,
implicitly configured for you. See `defaultConfiguration` for more information.
-}
webgl : (Int,Int) -> List Renderable -> Element
webgl =
  webglWithConfig defaultConfiguration


{-| Render a WebGL scene with the given dimensions and entities. Shaders and
meshes are cached so that they do not get resent to the GPU, so it should be
relatively cheap to create new entities out of existing values.
-}
webglWithConfig : List FunctionCall -> (Int,Int) -> List Renderable -> Element
webglWithConfig functionCalls dimensions entities =
  computeAPICalls functionCalls
  |> Native.WebGL.webgl dimensions entities


{-| -}
computeAPICalls : List FunctionCall -> List (a -> b)
computeAPICalls functionCalls =
  List.map
    computeAPICall
    functionCalls


{-| -}
computeAPICall : FunctionCall -> (a -> b)
computeAPICall function =
  case function of
    Enable capability ->
      computeCapabilityString capability
      |> Native.WebGL.enable

    Disable capability ->
      computeCapabilityString capability
      |> Native.WebGL.disable

    BlendColor (r, g, b, a) ->
      Native.WebGL.blendColor r g b a

    BlendEquation mode ->
      computeBlendModeString mode
      |> Native.WebGL.blendEquation

    BlendEquationSeparate (modeRGB', modeAlpha') ->
      let modeRGB = computeBlendModeString modeRGB'
          modeAlpha = computeBlendModeString modeAlpha'
      in Native.WebGL.blendEquationSeparate modeRGB modeAlpha

    BlendFunc (src', dst') ->
      let src = computeBlendOperationString src'
          dst = computeBlendOperationString dst'
      in Native.WebGL.blendFunc src dst

    DepthFunc mode ->
      computeCompareModeString mode
      |> Native.WebGL.depthFunc

    SampleCoverageFunc (value, invert) ->
      Native.WebGL.sampleCoverage value invert

    StencilFunc (func, ref, mask) ->
      let mode = computeCompareModeString func
      in Native.WebGL.stencilFunc mode ref mask

    StencilFuncSeparate (face', func, ref, mask) ->
      let face = computeFaceModeString face'
          mode = computeCompareModeString func
      in Native.WebGL.stencilFuncSeparate face mode ref mask

    StencilOperation (fail', zfail', zpass') ->
      let fail = computeZModeString fail'
          zfail = computeZModeString zfail'
          zpass = computeZModeString zpass'
      in Native.WebGL.stencilOperation fail zfail zpass

    StencilOperationSeparate (face', fail', zfail', zpass') ->
      let face = computeFaceModeString face'
          fail = computeZModeString fail'
          zfail = computeZModeString zfail'
          zpass = computeZModeString zpass'
      in Native.WebGL.stencilOperationSeparate face fail zfail zpass


{-| The `FunctionCall` provides a typesafe way to call
all pre-fragment operations and some special functions.

`Enable(capability: Capability)`
+ enable server-side GL capabilities

`Disable(cap: Capability)`
+ disable server-side GL capabilities

`BlendColor(red: Float, green: Float, blue: Float, alpha: Float)`
+ set the blend color

`BlendEquation(mode: BlendMode)`
+ specify the equation used for both the
RGB blend equation and the Alpha blend equation
+ `mode`: specifies how source and destination colors are combined

`BlendEquationSeparate(modeRGB: BlendMode, modeAlpha: BlendMode)`
+ set the RGB blend equation and the alpha blend equation separately
+ `modeRGB`: specifies the RGB blend equation, how the red, green,
and blue components of the source and destination colors are combined
+ `modeAlpha`: specifies the alpha blend equation, how the alpha component
of the source and destination colors are combined

`BlendFunc(srcFactor: BlendMode, dstFactor: BlendMode)`
+ specify pixel arithmetic
+ `srcFactor`: Specifies how the red, green, blue,
and alpha source blending factors are computed
+ `dstFactor`: Specifies how the red, green, blue,
and alpha destination blending factors are computed
+ `SrcAlphaSaturate` should only be used for the srcFactor);
+ Both values may not reference a `ConstantColor` value;

`SampleCoverageFunc(value: Float, invert: Bool)`
+ specify multisample coverage parameters
+ `value`: Specify a single floating-point sample coverage value.
The value is clamped to the range 0 1 . The initial value is `1`
+ `invert`: Specify a single boolean value representing
if the coverage masks should be inverted. The initial value is `False`

`StencilFunc(func: CompareMode, ref: Int, mask: Int)`
+ set front and back function and reference value for stencil testing
+ `func`: Specifies the test function.  The initial value is `Always`
+ `ref`: Specifies the reference value for the stencil test. ref is
clamped to the range 0 2 n - 1 , where n is the number of bitplanes
in the stencil buffer. The initial value is `0`.
+ `mask`: Specifies a mask that is ANDed with both the reference value
and the stored stencil value when the test is done.
The initial value is all `1`'s.

`StencilFuncSeparate(face: FaceMode, func: CompareMode, ref: Int, mask: Int)`
+ set front and/or back function and reference value for stencil testing
+ `face`: Specifies whether front and/or back stencil state is updated
+ see the description of `StencilFunc` for info about the other parameters

`StencilOperation(fail: ZMode, zfail: ZMode, pass: ZMode)`
+ set front and back stencil test actions
+ `fail`: Specifies the action to take when the stencil test fails.
The initial value is `Keep`
+ `zfail`: Specifies the stencil action when the stencil test passes,
but the depth test fails. The initial value is `Keep`
+ `pass`: Specifies the stencil action when both the stencil test
and the depth test pass, or when the stencil test passes and either
there is no depth buffer or depth testing is not enabled.
The initial value is `Keep`

`StencilOperationSeparate(face: FaceMode, fail: ZMode, zfail: ZMode, pass: Zmode)`
+ set front and/or back stencil test actions
+ `face`: Specifies whether front and/or back stencil state is updated.
+ See the description of `StencilOperation` for info about the other parameters.
-}
type FunctionCall
  = Enable Capability
  | Disable Capability
  | BlendColor (Float, Float, Float, Float)
  | BlendEquation BlendMode
  | BlendEquationSeparate (BlendMode, BlendMode)
  | BlendFunc (BlendOperation, BlendOperation)
  | DepthFunc CompareMode
  | SampleCoverageFunc (Float, Bool)
  | StencilFunc (CompareMode, Int, Int)
  | StencilFuncSeparate (FaceMode, CompareMode, Int, Int)
  | StencilOperation (ZMode, ZMode, ZMode)
  | StencilOperationSeparate (FaceMode, ZMode, ZMode, ZMode)


{-| -}
computeCapabilityString : Capability -> String
computeCapabilityString capability =
  case capability of
    Blend ->
      "BLEND"

    CullFace ->
      "CULL_FACE"

    DepthTest ->
      "DEPTH_TEST"

    Dither ->
      "DITHER"

    PolygonOffsetFill ->
      "POLYGON_OFFSET_FILL"

    SampleAlphaToCoverage ->
      "SAMPLE_ALPHA_TO_COVERAGE"

    SampleCoverage ->
      "SAMPLE_COVERAGE"

    ScissorTest ->
      "SCISSOR_TEST"

    StencilTest ->
      "STENCIL_TEST"


{-| The `Capability` type is used to enable/disable server-side GL capabilities.

+ `Blend`: If enabled, blend the computed fragment color values
with the values in the color buffers.
+ `CullFace`: If enabled, cull polygons based on their winding in window coordinates.
+ `DepthTest`: If enabled, do depth comparisons and update the depth buffer.
+ `Dither`: If enabled, dither color components.
or indices before they are written to the color buffer.
+ `PolygonOffsetFill`: If enabled, an offset is added
to depth values of a polygon's fragments produced by rasterization.
+ `SampleAlphaToCoverage`: If enabled, compute a temporary coverage value
where each bit is determined by the alpha value at the corresponding sample location.
The temporary coverage value is then ANDed with the fragment coverage value.
+ `SampleCoverage`: If enabled, the fragment's coverage
is ANDed with the temporary coverage value.
+ `ScissorTest`: If enabled, discard fragments that are outside the scissor rectangle
+ `StencilTest`: If enabled, do stencil testing and update the stencil buffer.
-}
type Capability
  = Blend
  | CullFace
  | DepthTest
  | Dither
  | PolygonOffsetFill
  | SampleAlphaToCoverage
  | SampleCoverage
  | ScissorTest
  | StencilTest


{-| -}
computeBlendOperationString : BlendOperation -> String
computeBlendOperationString operation =
  case operation of
    Zero ->
      "ZERO"

    One ->
      "ONE"

    SrcColor ->
      "SRC_COLOR"

    OneMinusSrcColor ->
      "ONE_MINUS_SRC_COLOR"

    DstColor ->
      "DST_COLOR"

    OneMinusDstColor ->
      "ONE_MINUS_DST_COLOR"

    SrcAlpha ->
      "SRC_ALPHA"

    OneMinusSrcAlpha ->
      "ONE_MINUS_SRC_ALPHA"

    DstAlpha ->
      "DST_ALPHA"

    OneMinusDstAlpha ->
      "ONE_MINUS_DST_ALPHA"

    ConstantColor ->
      "CONSTANT_COLOR"

    OneMinusConstantColor ->
      "ONE_MINUS_CONSTANT_COLOR"

    ConstantAlpha ->
      "CONSTANT_ALPHA"

    OneMinusConstantAlpha ->
      "ONE_MINUS_CONSTANT_ALPHA"

    SrcAlphaSaturate ->
      "SRC_ALPHA_SATURATE"


{-| The `BlendOperation` type allows you to define which blend operation to use.
-}
type BlendOperation
  = Zero
  | One
  | SrcColor
  | OneMinusSrcColor
  | DstColor
  | OneMinusDstColor
  | SrcAlpha
  | OneMinusSrcAlpha
  | DstAlpha
  | OneMinusDstAlpha
  | ConstantColor
  | OneMinusConstantColor
  | ConstantAlpha
  | OneMinusConstantAlpha
  | SrcAlphaSaturate


{-| -}
computeBlendModeString : BlendMode -> String
computeBlendModeString mode =
  case mode of
    Add ->
      "FUNC_ADD"

    Subtract ->
      "FUNC_SUBTRACT"

    ReverseSubtract ->
      "FUNC_REVERSE_SUBTRACT"


{-| The `BlendMode` type allows you to define which blend mode to use.
-}
type BlendMode
  = Add
  | Subtract
  | ReverseSubtract


{-| -}
computeCompareModeString : CompareMode -> String
computeCompareModeString mode =
  case mode of
    Never ->
      "NEVER"

    Always ->
      "ALWAYS"

    Less ->
      "LESS"

    LessOrEqual ->
      "LEQUAL"

    Equal ->
      "EQUAL"

    GreaterOrEqual ->
      "GEQUAL"

    Greater ->
      "Greater"

    NotEqual ->
      "NOTEQUAL"


{-| The `CompareMode` type allows you to define how to compare values.
-}
type CompareMode
  = Never
  | Always
  | Less
  | LessOrEqual
  | Equal
  | GreaterOrEqual
  | Greater
  | NotEqual


{-| -}
computeFaceModeString : FaceMode -> String
computeFaceModeString mode =
  case mode of
    Front ->
      "FRONT"

    Back ->
      "BACK"

    FrontAndBack ->
      "FRONT_AND_BACK"


{-| The `FaceMode` type defines which face of the stencil state is updated.
-}
type FaceMode
  = Front
  | Back
  | FrontAndBack


{-| -}
computeZModeString : ZMode -> String
computeZModeString mode =
  case mode of
    Keep ->
      "KEEP"

    None ->
      "ZERO"

    Replace ->
      "REPLACE"

    Increment ->
      "INCREMENT"

    Decrement ->
      "DECREMENT"

    Invert ->
      "INVERT"

    IncrementWrap ->
      "INCREMENT_WRAP"

    DecrementWrap ->
      "DECREMENT_WRAP"


{-| The `ZMode` type allows you to define what to do with the stencil buffer value.

+ `Keep`: Keeps the current value.
+ `None`: Sets the stencil buffer value to 0.
+ `Replace`: Sets the stencil buffer value to `ref`,
See `StencilFunc` for more information.
+ `Increment`: Increments the current stencil buffer value.
Clamps to the maximum representable unsigned value.
+ `Decrement`: Decrements the current stencil buffer value. Clamps to 0.
+ `Invert`: Bitwise inverts the current stencil buffer value.
+ `IncrementWrap`: Increments the current stencil buffer value.
Wraps stencil buffer value to zero when incrementing
the maximum representable unsigned value.
+ `DecrementWrap`: Decrements the current stencil buffer value.
Wraps stencil buffer value to the maximum representable unsigned
value when decrementing a stencil buffer value of zero.
-}
type ZMode
  = Keep
  | None
  | Replace
  | Increment
  | Decrement
  | Invert
  | IncrementWrap
  | DecrementWrap
