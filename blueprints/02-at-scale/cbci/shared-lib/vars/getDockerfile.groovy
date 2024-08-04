// vars/getDockerfile

def call(String dockerfileName){
    dockerfileContent = libraryResource "dockerfiles/${dockerfileName}"
    writeFile file: 'Dockerfile', text: dockerfileContent
}
