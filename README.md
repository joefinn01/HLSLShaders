# HLSLShaders
Some examples of shaders I created using HLSL for my university module (further games and graphics).

The billboarding shader uses the geometry shader to create a plane that is always perpendicular to the camera. This can be used for various different effects such as UI elements or trees at range in order to reduce the poly count.

The DX11 shader implements all the different types of lights (ambient, diffuse and specular) along with different types of light sources (spotlight, pointlight and directional light). On top of this I have also implemented fog in the pixel shader.
