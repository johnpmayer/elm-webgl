import Mouse
import Window
import Signal exposing (map, map2)
import WebGL as GL
import Math.Vector3 exposing (..)
import Math.Vector2 exposing (..)
import Math.Matrix4 as Mat4
import Graphics.Element exposing (..)

main = map view Mouse.position 


type alias Vertex = { position : Vec2, color : Vec3 }

mesh : GL.Drawable Vertex
mesh = GL.Triangle <|
    [ ( Vertex (vec2 0  0 ) (vec3 1 0 0)
      , Vertex (vec2 1  1 ) (vec3 0 1 0)
      , Vertex (vec2 1 0 ) (vec3 0 0 1)
      ),
      ( Vertex (vec2 0  0 ) (vec3 1 0 0)
      , Vertex (vec2 0  1 ) (vec3 0 0 1)
      , Vertex (vec2 1 1 ) (vec3 0 1 0)
      )
    ]


ortho2D w h = Mat4.makeOrtho2D 0 w h 0



view : (Int,Int)  -> Element 
view (w,h) =
  let matrix = ortho2D 1 1
  in GL.webgl (w,h)
    [ GL.render vertexShader fragmentShader mesh { mat = matrix } ]


-- Shaders

vertexShader : GL.Shader { attr | position:Vec2, color:Vec3 } { unif | mat:Mat4.Mat4 } { vcolor:Vec3 }
vertexShader = [glsl|

attribute vec2 position;
attribute vec3 color;
uniform mat4 mat;
varying vec3 vcolor;

void main () {
    gl_Position = mat * vec4(position, 0.0, 1.0);
    vcolor = color;
}

|]


fragmentShader : GL.Shader {} u { vcolor:Vec3 }
fragmentShader = [glsl|

precision mediump float;
varying vec3 vcolor;

void main () {
    gl_FragColor = vec4(vcolor, 1.0);
}

|]
