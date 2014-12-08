module WebGL where

{-| The WebGL API is for high performance rendering. Definitely read about
[how WebGL works](https://github.com/johnpmayer/elm-webgl/blob/master/README.md)
and look at some examples before trying to do too much with just the
documentation provided here.

# Triangles
@docs Triangle, map, map2

# Entities
@docs entity

# WebGL Element
@docs webgl

# Loading Textures
@docs loadTexture

# Unsafe Shader Creation (for library writers)
@docs unsafeShader

-}

import Graphics.Element (Element)
import Http (Response)
import Native.WebGL
import Signal (Signal)


{-| Triangles are the basic building blocks of a mesh. You can put them together
to form any shape. Each corner of a triangle is called a *vertex* and contains a
bunch of *attributes* that describe that particular corner. These attributes can
be things like position and color.

So when you create a `Triangle` you are really providing three sets of attributes
that describe the corners of a triangle.
-}
type alias Triangle attributes =
    (attributes, attributes, attributes)


{-| Apply a function to each vertex. This lets you transform the set of
attributes associated with each corner of a triangle.
-}
map : (a -> b) -> Triangle a -> Triangle b
map f (x,y,z) =
    (f x, f y, f z)


{-| Combine two triangles by putting each of their vertices together with
a given function.
-}
map2 : (a -> b -> c) -> Triangle a -> Triangle b -> Triangle c
map2 f (x,y,z) (x',y',z') =
    (f x x', f y y', f z z')


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


type Texture = Texture


{-| Loads a texture from the given url. PNG and JPEG are known to work, but
other formats have not been as well-tested yet.
-}
loadTexture : String -> Signal (Response Texture)
loadTexture =
  Native.WebGL.loadTex


type Entity = Entity 


{-| Packages a vertex shader, a fragment shader, a mesh, and uniform variables
as an `Entity`. This specifies a full rendering pipeline to be run on the GPU.
You can read more about the pipeline
[here](https://github.com/johnpmayer/elm-webgl/blob/master/README.md).

Values will be cached intelligently, so if you have already sent a shader or
mesh to the GPU, it will not be resent. This means it is fairly cheap to create
new entities if you are reusing shaders and meshes that have been used before.
-}
entity : Shader attributes uniforms varyings -> Shader {} uniforms varyings -> List (Triangle attributes) -> uniforms -> Entity
entity =
  Native.WebGL.entity


{-| Render a WebGL scene with the given dimensions and entities. Shaders and
meshes are cached so that they do not get resent to the GPU, so it should be
relatively cheap to create new entities out of existing values.
-}
webgl : (Int,Int) -> List Entity -> Element
webgl =
  Native.WebGL.webgl
