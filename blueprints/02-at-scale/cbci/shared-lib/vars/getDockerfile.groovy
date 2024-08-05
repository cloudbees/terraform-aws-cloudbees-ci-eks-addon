// vars/getDockerfile

def call(String fileName){
    if (fileName?.trim()) {
        Object dockerfileContent = libraryResource "dockerfiles/${fileName}"
        writeFile file: 'Dockerfile', text: dockerfileContent
    } else {
        error 'fileName is empty. Please provide a valid location.'
    }
}
