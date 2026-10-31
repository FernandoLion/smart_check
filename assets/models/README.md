# mobile_facenet.tflite

Modelo de embeddings faciales que usa la verificación de identidad antes de
emitir la baliza (`lib/services/reconocimiento_facial_service.dart`).

- Origen: Qualcomm AI Hub, versión v0.65.0, precisión float
  (`mobile_facenet-tflite-float.zip`), publicado en
  https://huggingface.co/qualcomm/MobileFaceNet
- Modelo original: https://github.com/foamliu/MobileFaceNet (Apache-2.0).
  El código de Qualcomm que lo exporta es BSD-3-Clause.
- SHA-256: `2046ab776fba2ec7e420767ffe7eb74a7402a8412d3d7ea8b9f4ca8420e5f3d7`

Entradas y salida (de `metadata.json` del zip):

- `img1` e `img2`: `float32 [1, 3, 112, 112]`, RGB, valores de 0 a 1. El
  modelo normaliza por dentro.
- `embeddings`: `float32 [2, 128]`, una fila por imagen, sin normalizar.
- Qualcomm compara por ángulo: menos de 74,18° es la misma persona
  (coseno ≈ 0,27). Nuestro umbral se calibra con pruebas reales.

Para la tesis: el modelo original se entrenó con una versión depurada de
MS-Celeb-1M, un conjunto de fotos que Microsoft retiró en 2019.
