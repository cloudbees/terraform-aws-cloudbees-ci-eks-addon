// vars/getDockerfile

def call(String filePath){
    if (filePath?.trim()) {
        Object dockerfileContent = libraryResource "dockerfiles/${filePath}"
        writeFile file: 'Dockerfile', text: dockerfileContent
    } else {
        error 'filePath is empty. Please provide a valid location.'
    }
}
