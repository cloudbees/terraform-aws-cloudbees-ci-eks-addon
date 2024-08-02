
def call(boolean skipTests = true) {
    if (skipTests) {
        sh 'mvn clean package -DskipTests -Dmaven.repo.local=./maven-repo'
    } else {
        sh 'mvn -Dmaven.test.failure.ignore=true install'
    }
}
