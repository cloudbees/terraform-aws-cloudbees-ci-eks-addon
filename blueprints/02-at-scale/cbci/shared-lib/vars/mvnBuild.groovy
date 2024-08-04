// vars/mvnBuild

def call(boolean skipTests=false){
	if (skipTests) {
		sh 'mvn clean package -DskipTests -Dmaven.repo.local=./maven-repo'
	} else {
		sh 'mvn clean package -Dmaven.repo.local=./maven-repo'
	}
}