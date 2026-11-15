package com.example.vitrine.feature.timer.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke

/** Icônes plates des chronos, dessinées en code (aucune bibliothèque d'icônes nécessaire). */

/** Triangle « lecture », légèrement décalé à droite pour paraître centré. */
@Composable
fun PlayIcon(color: Color, modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val w = size.width
        val h = size.height
        val path = Path().apply {
            moveTo(w * 0.30f, h * 0.18f)
            lineTo(w * 0.84f, h * 0.50f)
            lineTo(w * 0.30f, h * 0.82f)
            close()
        }
        drawPath(path, color)
        drawPath(path, color, style = Stroke(width = w * 0.08f, join = StrokeJoin.Round))
    }
}

/** Deux barres arrondies « pause ». */
@Composable
fun PauseIcon(color: Color, modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val barWidth = size.width * 0.22f
        val radius = CornerRadius(barWidth / 2)
        listOf(0.22f, 0.56f).forEach { x ->
            drawRoundRect(
                color = color,
                topLeft = Offset(size.width * x, size.height * 0.18f),
                size = Size(barWidth, size.height * 0.64f),
                cornerRadius = radius,
            )
        }
    }
}

/** Carré arrondi « arrêt ». */
@Composable
fun StopIcon(color: Color, modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val side = size.minDimension * 0.56f
        drawRoundRect(
            color = color,
            topLeft = Offset((size.width - side) / 2, (size.height - side) / 2),
            size = Size(side, side),
            cornerRadius = CornerRadius(side * 0.22f),
        )
    }
}

/** Croix « ajouter ». */
@Composable
fun PlusIcon(color: Color, modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val stroke = size.minDimension * 0.14f
        val inset = size.minDimension * 0.18f
        drawLine(color, Offset(center.x, inset), Offset(center.x, size.height - inset), stroke, StrokeCap.Round)
        drawLine(color, Offset(inset, center.y), Offset(size.width - inset, center.y), stroke, StrokeCap.Round)
    }
}

/** Trait « moins », dans le même style que la croix « ajouter ». */
@Composable
fun MinusIcon(color: Color, modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val stroke = size.minDimension * 0.14f
        val inset = size.minDimension * 0.18f
        drawLine(color, Offset(inset, center.y), Offset(size.width - inset, center.y), stroke, StrokeCap.Round)
    }
}

/** Crayon « modifier » : un trait épais en diagonale avec une pointe. */
@Composable
fun EditIcon(color: Color, modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val stroke = size.minDimension * 0.14f
        val start = Offset(size.width * 0.24f, size.height * 0.76f)
        val end = Offset(size.width * 0.74f, size.height * 0.26f)
        drawLine(color, start, end, stroke, StrokeCap.Round)
        // Pointe du crayon
        drawLine(
            color,
            Offset(size.width * 0.16f, size.height * 0.84f),
            Offset(size.width * 0.20f, size.height * 0.80f),
            stroke,
            StrokeCap.Round,
        )
    }
}

/** Corbeille « supprimer » : couvercle, poignée et cuve aux coins arrondis. */
@Composable
fun TrashIcon(color: Color, modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val w = size.width
        val h = size.height
        val stroke = size.minDimension * 0.12f
        // Couvercle et poignée
        drawLine(color, Offset(w * 0.14f, h * 0.24f), Offset(w * 0.86f, h * 0.24f), stroke, StrokeCap.Round)
        drawLine(color, Offset(w * 0.38f, h * 0.10f), Offset(w * 0.62f, h * 0.10f), stroke, StrokeCap.Round)
        // Cuve
        drawRoundRect(
            color = color,
            topLeft = Offset(w * 0.24f, h * 0.34f),
            size = Size(w * 0.52f, h * 0.58f),
            cornerRadius = CornerRadius(w * 0.08f),
            style = Stroke(width = stroke),
        )
    }
}
