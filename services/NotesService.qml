pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property var notes: []
    property var tasks: []
    property var activeTask: null
    property bool loaded: false
    property string errorMessage: ""
    property string saveState: ""
    property int revision: 0
    property string pendingId: ""
    property string pendingTitle: ""
    property string pendingContent: ""

    readonly property string helperPath:
        Quickshell.shellDir + "/scripts/notesctl.py"

    signal noteCreated(string noteId)
    signal noteDeleted(string noteId)

    function cloneNotes(): var {
        return notes.map(note => ({
            id: note.id,
            title: note.title,
            content: note.content,
            updated: note.updated
        }))
    }

    function note(noteId: string): var {
        return notes.find(candidate => candidate.id === noteId) || null
    }

    function replaceNote(nextNote): void {
        const updated = cloneNotes()
        const index = updated.findIndex(candidate => candidate.id === nextNote.id)
        if (index >= 0)
            updated[index] = nextNote
        else
            updated.unshift(nextNote)
        updated.sort((left, right) => right.updated.localeCompare(left.updated))
        notes = updated
        revision += 1
    }

    function refresh(): void {
        enqueue({ kind: "list", command: [helperPath, "list"] })
    }

    function createNote(): void {
        flushPendingSave()
        enqueue({ kind: "create", command: [helperPath, "create"] })
    }

    function updateNote(noteId: string, title: string, content: string): void {
        const current = note(noteId)
        if (!current)
            return
        const updated = cloneNotes()
        const index = updated.findIndex(candidate => candidate.id === noteId)
        updated[index] = {
            id: noteId,
            title: title,
            content: content,
            updated: current.updated
        }
        notes = updated
        revision += 1
        pendingId = noteId
        pendingTitle = title
        pendingContent = content
        saveState = "Saving…"
        savedStateTimer.stop()
        autosave.restart()
    }

    function flushPendingSave(): void {
        if (!pendingId)
            return
        autosave.stop()
        const task = {
            kind: "save",
            noteId: pendingId,
            command: [helperPath, "save", pendingId],
            payload: JSON.stringify({
                title: pendingTitle,
                content: pendingContent
            }) + "\n"
        }
        pendingId = ""
        tasks = tasks.filter(candidate =>
            candidate.kind !== "save" || candidate.noteId !== task.noteId)
        enqueue(task)
    }

    function deleteNote(noteId: string): void {
        if (!note(noteId))
            return
        if (pendingId === noteId) {
            pendingId = ""
            autosave.stop()
        }
        tasks = tasks.filter(candidate =>
            candidate.kind !== "save" || candidate.noteId !== noteId)
        enqueue({
            kind: "delete",
            noteId: noteId,
            command: [helperPath, "delete", noteId]
        })
    }

    function enqueue(task): void {
        tasks = tasks.concat([task])
        runNext()
    }

    function runNext(): void {
        if (process.running || activeTask || tasks.length === 0)
            return
        activeTask = tasks[0]
        tasks = tasks.slice(1)
        stdoutBuffer = ""
        stderrBuffer = ""
        process.command = activeTask.command
        process.stdinEnabled = Boolean(activeTask.payload)
        process.running = true
    }

    function handleSuccess(response): void {
        const kind = activeTask.kind
        if (kind === "list") {
            notes = Array.isArray(response.notes) ? response.notes : []
            loaded = true
            revision += 1
        } else if (kind === "create") {
            replaceNote(response)
            noteCreated(response.id)
        } else if (kind === "save") {
            replaceNote(response)
            if (!pendingId && !tasks.some(task => task.kind === "save")) {
                saveState = "Saved"
                savedStateTimer.restart()
            }
        } else if (kind === "delete") {
            notes = cloneNotes().filter(note => note.id !== activeTask.noteId)
            revision += 1
            noteDeleted(activeTask.noteId)
            if (!pendingId)
                saveState = ""
        }
    }

    property string stdoutBuffer: ""
    property string stderrBuffer: ""

    property Timer autosave: Timer {
        interval: 550
        repeat: false
        onTriggered: root.flushPendingSave()
    }

    property Timer savedStateTimer: Timer {
        interval: 1600
        repeat: false
        onTriggered: root.saveState = ""
    }

    property Process process: Process {
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.stdoutBuffer = text.trim()
        }
        stderr: StdioCollector {
            onStreamFinished: root.stderrBuffer = text.trim()
        }
        onStarted: {
            if (root.activeTask?.payload)
                write(root.activeTask.payload)
        }
        onExited: exitCode => {
            const task = root.activeTask
            if (exitCode === 0) {
                try {
                    root.handleSuccess(root.stdoutBuffer
                        ? JSON.parse(root.stdoutBuffer) : ({}))
                    root.errorMessage = ""
                } catch (error) {
                    root.errorMessage = "Notes could not be read"
                    console.warn("Odyssey NotesService:", error)
                }
            } else {
                root.errorMessage = root.stderrBuffer || "Notes operation failed"
                if (task?.kind === "save")
                    root.saveState = ""
                if (task?.kind === "list")
                    root.loaded = true
                console.warn("Odyssey NotesService:", root.errorMessage)
            }
            root.activeTask = null
            Qt.callLater(root.runNext)
        }
    }

    Component.onCompleted: refresh()
}
