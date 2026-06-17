import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "board",
    "status",
    "finishButton",
    "finishForm",
    "tryAgainButton",
    "hintButton",
    "hintPanel",
    "hintText",
    "revealPanel",
  ];
  static values = {
    fen: String,
    solutionLine: String,
    hintText: String,
    hintSquare: String,
    skipUrl: String,
    completeUrl: String,
    reveal: { type: Object, default: {} },
  };

  #moveListener = null;

  connect() {
    this.solutionIndex = 0;
    this.solved = false;
    this.awaitingRetry = false;
    this.hintShown = false;
  }

  boardTargetConnected() {
    this.#attachMoveListener();
  }

  boardTargetDisconnected() {
    this.#detachMoveListener();
  }

  disconnect() {
    this.#detachMoveListener();
  }

  onUserMove(event) {
    if (this.solved || this.awaitingRetry) {
      return;
    }

    const uci = event.detail?.uci;
    const expected = this.#solutionMoves()[this.solutionIndex];

    if (!uci || !expected || uci !== expected) {
      this.awaitingRetry = true;
      this.#boardController()?.disableInput();
      this.#setStatus("Incorrect move. Try again.");
      this.#showTryAgain();

      return;
    }

    this.#hideTryAgain();

    this.solutionIndex += 1;

    if (this.solutionIndex >= this.#solutionMoves().length) {
      this.#markSolved();

      return;
    }

    this.#playOpponentReply();
  }

  #solutionMoves() {
    return this.solutionLineValue.split(/\s+/).filter(Boolean);
  }

  #playOpponentReply() {
    const board = this.#boardController();
    const opponentUci = this.#solutionMoves()[this.solutionIndex];

    this.#setStatus("Correct! Opponent responds...");

    window.setTimeout(() => {
      board.playUci(opponentUci);

      this.solutionIndex += 1;

      if (this.solutionIndex >= this.#solutionMoves().length) {
        this.#markSolved();
      } else {
        this.#setStatus("Find the next move.");
      }
    }, 400);
  }

  #markSolved() {
    this.solved = true;

    this.#boardController()?.disableInput();
    this.#clearHint();

    const message = this.revealValue?.played_uci
      ? "Correct!"
      : "Puzzle solved!";

    this.#setStatus(message, { success: true });
    this.#showReveal();
    this.#setFinishAction("complete");
  }

  tryAgain() {
    void this.#resetPuzzle("Find the best move.");
  }

  showHint() {
    if (this.solved || this.awaitingRetry || this.hintShown) {
      return;
    }

    this.hintShown = true;

    if (this.hasHintTextTarget) {
      this.hintTextTarget.textContent = this.hintTextValue;
    }

    if (this.hasHintPanelTarget) {
      this.hintPanelTarget.classList.remove("hidden");
    }

    this.#boardController()?.showHintMarker(this.#currentHintSquare());

    if (this.hasHintButtonTarget) {
      this.hintButtonTarget.disabled = true;
    }
  }

  async #resetPuzzle(message) {
    this.solutionIndex = 0;
    this.solved = false;
    this.awaitingRetry = false;

    const board = this.#boardController();

    await board?.resetToFen(this.fenValue);
    this.#clearHint();
    this.#hideReveal();
    this.#setStatus(message);
    this.#hideTryAgain();
    this.#setFinishAction("skip");
  }

  #showTryAgain() {
    if (this.hasTryAgainButtonTarget) {
      this.tryAgainButtonTarget.classList.remove("hidden");
    }
  }

  #hideTryAgain() {
    if (this.hasTryAgainButtonTarget) {
      this.tryAgainButtonTarget.classList.add("hidden");
    }
  }

  #setStatus(message, { success = false } = {}) {
    if (!this.hasStatusTarget) {
      return;
    }

    this.statusTarget.textContent = message;
    this.statusTarget.classList.toggle("text-green-700", success);
    this.statusTarget.classList.toggle("text-gray-900", !success);
  }

  #setFinishAction(mode) {
    if (!this.hasFinishButtonTarget || !this.hasFinishFormTarget) {
      return;
    }

    const button = this.finishButtonTarget;
    const form = this.finishFormTarget;
    const complete = mode === "complete";

    form.action = complete ? this.completeUrlValue : this.skipUrlValue;
    button.textContent = complete ? "Complete" : "Skip";
    button.className = complete
      ? "rounded-lg bg-gray-900 px-4 py-2 text-sm font-medium text-white"
      : "rounded-lg border border-gray-300 px-4 py-2 text-sm font-medium text-gray-900";
  }

  #currentHintSquare() {
    const expected = this.#solutionMoves()[this.solutionIndex];

    return expected?.slice(0, 2) || this.hintSquareValue;
  }

  #clearHint() {
    this.hintShown = false;
    this.#boardController()?.clearMarkers();

    if (this.hasHintPanelTarget) {
      this.hintPanelTarget.classList.add("hidden");
    }

    if (this.hasHintButtonTarget) {
      this.hintButtonTarget.disabled = false;
    }
  }

  #showReveal() {
    const reveal = this.revealValue;

    if (!reveal?.played_uci) {
      return;
    }

    // Keep the board at the position after the user's correct move.

    if (!this.hasRevealPanelTarget) {
      return;
    }

    const parts = [
      `Played <span class="font-mono font-semibold">${reveal.played_san}</span>`,
    ];

    if (reveal.best_move_san) {
      parts.push(
        `Best <span class="font-mono font-semibold">${reveal.best_move_san}</span>`,
      );
    }

    if (reveal.classification) {
      parts.push(`<span class="capitalize">${reveal.classification}</span>`);
    }

    if (reveal.centipawn_loss != null) {
      parts.push(`CPL ${reveal.centipawn_loss}`);
    }

    this.revealPanelTarget.innerHTML = parts.join(" · ");
    this.revealPanelTarget.classList.remove("hidden");
  }

  #hideReveal() {
    if (!this.hasRevealPanelTarget) {
      return;
    }

    this.revealPanelTarget.innerHTML = "";
    this.revealPanelTarget.classList.add("hidden");
  }

  #attachMoveListener() {
    const board = this.#chessBoardElement();

    if (!board) {
      return;
    }

    this.#detachMoveListener();

    this.#moveListener = this.onUserMove.bind(this);

    board.addEventListener("chess-board:move", this.#moveListener);
  }

  #detachMoveListener() {
    const board = this.#chessBoardElement();

    if (!board || !this.#moveListener) {
      return;
    }

    board.removeEventListener("chess-board:move", this.#moveListener);

    this.#moveListener = null;
  }

  #chessBoardElement() {
    if (!this.hasBoardTarget) {
      return null;
    }

    if (this.boardTarget.matches('[data-controller~="chess-board"]')) {
      return this.boardTarget;
    }

    return this.boardTarget.querySelector('[data-controller~="chess-board"]');
  }

  #boardController() {
    const element = this.#chessBoardElement();

    if (!element) {
      return null;
    }

    return this.application.getControllerForElementAndIdentifier(
      element,
      "chess-board",
    );
  }
}
