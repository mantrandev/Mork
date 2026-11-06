import MorkDomain
import SwiftUI

struct RemoteSheet: View {
    @State var form: RemoteForm
    let onSave: (RemoteForm) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        DialogScaffold(
            kind: .form,
            glyph: form.isEditing ? "pencil" : "network",
            title: form.isEditing ? "Edit Remote \(form.original?.name ?? "")" : "Add Remote",
            message: form.isEditing
                ? "Renaming runs git remote rename, which also renames the remote-tracking branches and updates branches that track them. Leave Push URL empty to push to the same URL you fetch from."
                : "A remote is a named URL of another copy of this repository. Nothing is downloaded until you fetch."
        ) {
            VStack(alignment: .leading, spacing: Metrics.Sheet.rowSpacing) {
                DialogLabeledRow("Name") {
                    DialogTextField(placeholder: "origin", text: $form.name, identifier: "remoteSheet.name")
                }
                if let problem = form.nameProblem {
                    DialogLabeledRow(nil) {
                        DialogNote(text: problem, tone: .danger)
                            .accessibilityIdentifier("remoteSheet.problem")
                    }
                }
                DialogLabeledRow("URL") {
                    DialogTextField(placeholder: "https://github.com/user/repo.git or /path/to/repo.git", text: $form.url, identifier: "remoteSheet.url", isMonospaced: true)
                }
                if form.isEditing {
                    DialogLabeledRow("Push URL") {
                        DialogTextField(placeholder: "Same as URL", text: $form.pushURL, identifier: "remoteSheet.pushURL", isMonospaced: true)
                    }
                } else {
                    DialogLabeledRow(nil) {
                        DialogOptionToggle(title: "Fetch after adding", isOn: $form.fetchAfterAdd)
                            .accessibilityIdentifier("remoteSheet.fetch")
                    }
                }
            }
            if !form.isEditing {
                CommandStrip(command: DialogCommands.addRemote(name: form.name, url: form.url))
            }
        } buttons: {
            DialogCancelButton { dismiss() }
            DialogConfirmButton(title: form.isEditing ? "Save" : "Add Remote", identifier: "remoteSheet.confirm") {
                onSave(form)
                dismiss()
            }
            .disabled(!form.canSave)
        }
    }
}
