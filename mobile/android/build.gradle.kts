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
// Fix for pub packages that predate the AGP namespace requirement (e.g. telephony 0.2.0).
// pluginManager.withPlugin fires when the Android library plugin is applied (configuration
// phase), before AGP's finalizeDsl validates the namespace — avoiding the
// "Cannot run afterEvaluate when already evaluated" error.
subprojects {
    pluginManager.withPlugin("com.android.library") {
        extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)?.let { libExt ->
            if (libExt.namespace == null) {
                val manifest = file("src/main/AndroidManifest.xml")
                if (manifest.exists()) {
                    val pkg = Regex("""package\s*=\s*"([^"]+)"""")
                        .find(manifest.readText())
                        ?.groupValues?.get(1)
                    if (!pkg.isNullOrBlank()) {
                        libExt.namespace = pkg
                    }
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
