buildscript {
    repositories {
        google()
        mavenCentral()
        maven(url = uri("https://chaquo.com/maven"))
        gradlePluginPortal()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.6.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.2.0")
        classpath("com.chaquo.python:gradle:15.0.1")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        maven(url = uri("https://chaquo.com/maven"))
        maven(url = uri("https://jitpack.io"))
        maven(url = uri("https://artifactory.appodeal.com/appodeal-public"))
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
