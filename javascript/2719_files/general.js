function JumpToIt(list) {
    var newPage = list.options[list.selectedIndex].value
    if (newPage != "None") {
        location.href=newPage
    }
}