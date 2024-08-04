// vars/getDockerfile

def call(String dockerfileLocation){ 
    dockerfileContent = libraryResource "dockerfiles/${dockerfileLocation}"
    writeFile file: 'Dockerfile', text: dockerfileContent
}
