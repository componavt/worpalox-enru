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
// Plugin subprojects compile against the Flutter template SDK (33), but
// plugin dependencies (audioplayers -> androidx.window 1.2.0, jni) demand
// compileSdk 36. Override after each plugin evaluates its own config.
subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            (project.extensions.findByName("android") as?
                com.android.build.gradle.BaseExtension)?.compileSdkVersion(36)
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
