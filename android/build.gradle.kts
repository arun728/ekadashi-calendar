import com.android.build.api.variant.LibraryAndroidComponentsExtension

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
subprojects {
    project.evaluationDependsOn(":app")
}

// Billing's modern AndroidX dependencies require API36 at compile time.
// Older Flutter libraries hard-code 33/34. Finalize their DSL consistently;
// this does not raise minSdk or change supported device APIs.
subprojects {
    pluginManager.withPlugin("com.android.library") {
        extensions.configure<LibraryAndroidComponentsExtension> {
            finalizeDsl { dsl ->
                if ((dsl.compileSdk ?: 0) < 36) dsl.compileSdk = 36
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
