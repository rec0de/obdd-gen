plugins {
    java
    kotlin("jvm") version "1.5.10"
    application
    antlr
    id("com.github.johnrengelman.shadow") version "7.0.0"
}

group = "obdd"
version = "2.0"

repositories {
    mavenCentral()
}

dependencies {
    implementation(kotlin("stdlib"))
    testImplementation("org.junit.jupiter:junit-jupiter-api:5.6.0")
    testRuntimeOnly("org.junit.jupiter:junit-jupiter-engine")
    implementation("org.antlr:antlr4:4.8")
    antlr("org.antlr:antlr4:4.8")
}

sourceSets.getByName("main").java {
    srcDir("build/generated-src/main/java")
}

application {
    mainClass.set("obdd.MainKt")
}

tasks.generateGrammarSource {
    arguments = arguments + listOf("-visitor", "-long-messages")
    outputDirectory = file("build/generated-src/main/java/obdd/gen")
}

tasks.compileKotlin {
    dependsOn("generateGrammarSource")
}

tasks.getByName<Test>("test") {
    useJUnitPlatform()
}