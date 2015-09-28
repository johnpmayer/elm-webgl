-- Thanks to The PaperNES Guy for the texture:
-- http://the-papernes-guy.deviantart.com/art/Thwomps-Thwomps-Thwomps-186879685

import Graphics.Element exposing (..)
import Math.Vector2 exposing (Vec2)
import Math.Vector3 as V3 exposing (..)
import Math.Matrix4 exposing (..)
import Mouse
import Task exposing (Task, andThen)
import WebGL exposing (..)
import Window


-- SIGNALS

main : Signal Element
main =
  let
    perspectiveMatrix =
      Signal.map2 perspective Window.dimensions Mouse.position
  in
    Signal.map3 (view face sides) Window.dimensions textures.signal perspectiveMatrix


textures : Signal.Mailbox (Maybe Texture, Maybe Texture)
textures =
  Signal.mailbox (Nothing, Nothing)


port fetchTextures : Task WebGL.Error ()
port fetchTextures =
  loadTextureWithFilter Nearest "/examples/textures/thwomp_face.jpg"
  `andThen` \faceTexture ->
  loadTextureWithFilter Nearest "/examples/textures/thwomp_side.jpg"
  `andThen` \sideTexture ->
    Signal.send textures.address (Just faceTexture, Just sideTexture)


-- MESHES - define the mesh for a Thwomp's face

type alias Vertex =
    { position : Vec3, coord : Vec3 }


face : List (Drawable Vertex)
face =
    rotatedSquare (0,0)


sides : List (Drawable Vertex)
sides =
    List.concatMap rotatedSquare [ (90,0), (180,0), (270,0), (0,90), (0,-90) ]


{-| Apply a function to each vertex. This lets you transform the set of
attributes associated with each corner of a triangle.
-}
mapT : (a -> a) -> Drawable a -> Drawable a
mapT f a =
  case a of
    Triangle [(x, y, z)] ->
      Triangle [(f x, f y, f z)]
    _ -> a

rotatedSquare : (Float,Float) -> List (Drawable Vertex)
rotatedSquare (angleXZ,angleYZ) =
    let x = makeRotate (degrees angleXZ) j
        y = makeRotate (degrees angleYZ) i
        t = x `mul` y
    in
        List.map (mapT (\v -> {v | position <- transform t v.position })) square


square : List (Drawable Vertex)
square =
    let topLeft     = Vertex (vec3 -1  1 1) (vec3 0 1 0)
        topRight    = Vertex (vec3  1  1 1) (vec3 1 1 0)
        bottomLeft  = Vertex (vec3 -1 -1 1) (vec3 0 0 0)
        bottomRight = Vertex (vec3  1 -1 1) (vec3 1 0 0)
    in
        [ Triangle [(topLeft,    topRight, bottomLeft)]
        , Triangle [(bottomLeft, topRight, bottomRight)]
        ]


-- VIEW

perspective : (Int,Int) -> (Int,Int) -> Mat4
perspective (w',h') (x',y') =
    let w = toFloat w'
        h = toFloat h'
        x = toFloat x'
        y = toFloat y'

        distance = 6

        eyeX = distance * (w/2 - x) / w
        eyeY = distance * (y - h/2) / h
        eye = V3.scale distance (V3.normalize (vec3 eyeX eyeY distance))
    in
        mul (makePerspective 45 (w/h) 0.01 100)
            (makeLookAt eye (vec3 0 0 0) j)


view : List (Drawable Vertex)
    -> List (Drawable Vertex)
    -> (Int,Int)
    -> (Maybe Texture, Maybe Texture)
    -> Mat4
    -> Element
view mesh1 mesh2 dimensions (texture1, texture2) perspective =
    webgl dimensions
        (toEntity mesh1 texture1 perspective ++ toEntity mesh2 texture2 perspective)


toEntity : List (Drawable Vertex) -> Maybe Texture -> Mat4 -> List Renderable
toEntity mesh response perspective =
  response
  |> Maybe.map (\texture ->
                  List.map (\d ->
                              render vertexShader fragmentShader d
                                     { texture=texture, perspective=perspective })
                  mesh)
  |> Maybe.withDefault []


-- SHADERS

vertexShader : Shader { position:Vec3, coord:Vec3 } { u | perspective:Mat4 } { vcoord:Vec2 }
vertexShader = [glsl|

attribute vec3 position;
attribute vec3 coord;
uniform mat4 perspective;
varying vec2 vcoord;

void main () {
  gl_Position = perspective * vec4(position, 1.0);
  vcoord = coord.xy;
}

|]


fragmentShader : Shader {} { u | texture:Texture } { vcoord:Vec2 }
fragmentShader = [glsl|

precision mediump float;
uniform sampler2D texture;
varying vec2 vcoord;

void main () {
  gl_FragColor = texture2D(texture, vcoord);
}

|]
