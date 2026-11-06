package com.example.vitrine

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.example.vitrine.core.navigation.VitrineApp
import com.example.vitrine.ui.theme.VitrineTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            VitrineTheme {
                VitrineApp()
            }
        }
    }
}
