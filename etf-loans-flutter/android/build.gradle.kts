import com.android.build.api.variant.LibraryAndroidComponentsExtension

plugins {
    id("com.android.application") apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Flutter's target-platform flag does not filter native builds in library projects.
val arm64Only = providers.gradleProperty("etfArm64Only").orNull == "true"
subprojects {
    if (arm64Only && (path == ":jni" || path == ":jni_flutter")) {
        pluginManager.withPlugin("com.android.library") {
            extensions.getByType<LibraryAndroidComponentsExtension>().finalizeDsl { android ->
                android.defaultConfig.ndk.abiFilters.apply {
                    clear()
                    add("arm64-v8a")
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
