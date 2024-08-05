// vars/getDockerfile

def call(String dockerfileLocation){
    if (dockerfileLocation?.trim()) {
        Object dockerfileContent = libraryResource "dockerfiles/${dockerfileLocation}"
        writeFile file: 'Dockerfile', text: dockerfileContent
    } else {
        error 'dockerfileLocation is empty. Please provide a valid location.'
    }
}
