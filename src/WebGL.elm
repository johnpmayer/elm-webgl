module WebGL where

{-| The WebGL API is for high performance rendering. Definitely read about
[how WebGL works](https://github.com/johnpmayer/elm-webgl/blob/master/README.md)
and look at some examples before trying to do too much with just the
documentation provided here.

# Main Types
@docs Texture, TextureFilter, Shader, Entity, Error

# Triangles
@docs Triangle, map, map2

# Entities
@docs entity

# WebGL Element
@docs webgl

# Loading Textures
@docs loadTexture, loadTextureWithFilter, textureSize

# Unsafe Shader Creation (for library writers)
@docs unsafeShader

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

type RenderableType attributes
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
type Entity = Entity 

{-| Packages a vertex shader, a fragment shader, a mesh, and uniform variables
as an `Entity`. This specifies a full rendering pipeline to be run on the GPU.
You can read more about the pipeline
[here](https://github.com/johnpmayer/elm-webgl/blob/master/README.md).

Values will be cached intelligently, so if you have already sent a shader or
mesh to the GPU, it will not be resent. This means it is fairly cheap to create
new entities if you are reusing shaders and meshes that have been used before.
-}
entity : Shader attributes uniforms varyings -> Shader {} uniforms varyings -> (RenderableType attributes) -> uniforms -> Entity
entity =
  Native.WebGL.entity


{-| Render a WebGL scene with the given dimensions and entities. Shaders and
meshes are cached so that they do not get resent to the GPU, so it should be
relatively cheap to create new entities out of existing values.
-}
webgl : (Int,Int) -> List Entity -> Element
webgl =
  Native.WebGL.webgl
