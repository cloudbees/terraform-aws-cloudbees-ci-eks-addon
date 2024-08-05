// vars/mvnBuild

def call(Map args = [:]) {
	def skipTests = args.containsKey('skipTests') ? args.skipTests : error('mvnBuild: skipTests parameter is required')
	if (skipTests) {
		sh 'mvn clean package -DskipTests -Dmaven.repo.local=./maven-repo'
	} else {
		sh 'mvn clean package -Dmaven.repo.local=./maven-repo'
	}
}
