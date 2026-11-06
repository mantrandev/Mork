import MorkDomain
import Foundation

extension RepositoryViewModel {
    var effectiveCommitMessage: String {
        let text = commitMessage.text
        return commitTemplate.map { $0.cleaned(text) } ?? text
    }

    var isComposerUntouched: Bool {
        commitMessage.isEmpty || commitMessage == prefilledMessage
    }

    public func reloadCommitTemplate() async {
        startLoadingCommitTemplate()
        await commitTemplateTask?.value
    }

    public func waitForCommitTemplate() async {
        await commitTemplateTask?.value
    }

    func startLoadingCommitTemplate() {
        commitTemplateTask?.cancel()
        let load = dependencies.commit.loadCommitTemplate
        commitTemplateTask = Task { [weak self] in
            let template = try? await load.execute()
            guard !Task.isCancelled, let self else { return }
            self.show(template)
        }
    }

    func prefillCommitTemplate() {
        guard let template = commitTemplate, !isAmending, commitMessage.isEmpty else { return }
        let message = template.composerMessage
        commitSubject = message.subject
        commitDescription = message.description
        prefilledMessage = message
    }

    private func show(_ template: CommitTemplate?) {
        let wasUntouched = isComposerUntouched
        if commitTemplate != template { commitTemplate = template }
        guard wasUntouched, !isAmending else { return }
        commitSubject = ""
        commitDescription = ""
        prefilledMessage = nil
        prefillCommitTemplate()
    }
}
