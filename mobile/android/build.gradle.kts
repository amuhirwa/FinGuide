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

// Fix for pub packages that predate the AGP namespace requirement (e.g. telephony 0.2.0).
// Reads the package attribute from each library's AndroidManifest.xml and sets it as
// the namespace so AGP 7.3+ does not reject the build.
subprojects {
    afterEvaluate {
        if (project.plugins.hasPlugin("com.android.library")) {
            val libExt = project.extensions
                .findByType(com.android.build.gradle.LibraryExtension::class.java)
            if (libExt != null && libExt.namespace == null) {
                val manifest = project.file("src/main/AndroidManifest.xml")
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
