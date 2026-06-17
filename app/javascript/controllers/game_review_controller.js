import { Controller } from "@hotwired/stimulus";

const MISTAKE_CLASSIFICATIONS = ["inaccuracy", "mistake", "blunder"];

export default class extends Controller {
  #keyboardHandler = null;

  static targets = ["board", "comparison", "moveRow"];
  static values = {
    review: Object,
    initialPly: { type: Number, default: 0 },
    static: { type: Boolean, default: false },
  };

  connect() {
    if (this.staticValue && this.moves.length === 1) {
      this.currentIndex = 0;
    } else {
      this.currentIndex = this.#indexForPly(this.initialPlyValue);
    }

    this.mistakeFilter = null;

    this.#bindKeyboard();

    this.#chessBoardElement()?.addEventListener(
      "chess-board:ready",
      this.#handleBoardReady,
    );

    this.#handleBoardReady();
  }

  disconnect() {
    if (this.#keyboardHandler) {
      document.removeEventListener("keydown", this.#keyboardHandler);
    }

    this.#chessBoardElement()?.removeEventListener(
      "chess-board:ready",
      this.#handleBoardReady,
    );
  }

  #handleBoardReady = () => {
    this.#renderPosition();
    this.#updateFilterButtons();
  };

  prevMove() {
    if (this.currentIndex > 0) {
      this.currentIndex -= 1;

      this.#renderPosition();
    }
  }

  nextMove() {
    if (this.currentIndex < this.moves.length) {
      this.currentIndex += 1;

      this.#renderPosition();
    }
  }

  jumpToPly(event) {
    const ply = Number(event.params.ply);

    this.currentIndex = this.#indexForPly(ply);

    this.#renderPosition();
  }

  filterMistakes(event) {
    const classification = event.params.classification;
    this.mistakeFilter =
      this.mistakeFilter === classification ? null : classification;

    this.#updateFilterButtons();
    this.#jumpToNextMistake(1);
  }

  prevMistake() {
    this.#jumpToNextMistake(-1);
  }

  nextMistake() {
    this.#jumpToNextMistake(1);
  }

  get moves() {
    return this.reviewValue?.moves || [];
  }

  get startingFen() {
    return this.reviewValue?.starting_fen;
  }

  #indexForPly(ply) {
    if (!ply || ply <= 0) {
      return 0;
    }

    const index = this.moves.findIndex((move) => move.ply === ply);

    return index === -1 ? 0 : index + 1;
  }

  #bindKeyboard() {
    this.#keyboardHandler = (event) => {
      if (event.target.matches("input, textarea, select")) {
        return;
      }

      if (event.key === "ArrowLeft") {
        event.preventDefault();
        this.prevMove();
      } else if (event.key === "ArrowRight") {
        event.preventDefault();
        this.nextMove();
      }
    };

    document.addEventListener("keydown", this.#keyboardHandler);
  }

  #chessBoardElement() {
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

  #currentMove() {
    if (this.currentIndex === 0) {
      return null;
    }

    return this.moves[this.currentIndex - 1];
  }

  #renderPosition() {
    let fen;
    const board = this.#boardController();

    if (!board) {
      return;
    }

    const move = this.#currentMove();
    let comparisonMove = move;

    if (this.staticValue && this.moves.length === 1) {
      comparisonMove = this.moves[0];
      fen = comparisonMove.fen_before;
    } else {
      fen = move ? move.fen_after : this.startingFen;
    }

    board.setPosition(fen);

    if (comparisonMove?.played_by_user && comparisonMove.best_move_uci) {
      board.showArrows([
        {
          from: comparisonMove.uci.slice(0, 2),
          to: comparisonMove.uci.slice(2, 4),
          type: "danger",
        },
        {
          from: comparisonMove.best_move_uci.slice(0, 2),
          to: comparisonMove.best_move_uci.slice(2, 4),
          type: "success",
        },
      ]);

      this.#renderComparison(comparisonMove);
    } else {
      board.showArrows([]);
      this.#clearComparison();
    }

    this.#highlightMoveRow();
  }

  #renderComparison(move) {
    if (!this.hasComparisonTarget) {
      return;
    }

    const parts = [
      `Played <span class="font-mono font-semibold">${move.san}</span>`,
    ];

    if (move.best_move_san) {
      parts.push(
        `Best <span class="font-mono font-semibold">${move.best_move_san}</span>`,
      );
    }

    if (move.classification) {
      parts.push(`<span class="capitalize">${move.classification}</span>`);
    }

    if (move.centipawn_loss != null) {
      parts.push(`CPL ${move.centipawn_loss}`);
    }

    this.comparisonTarget.innerHTML = parts.join(" · ");

    this.comparisonTarget.classList.remove("hidden");
  }

  #clearComparison() {
    if (!this.hasComparisonTarget) return;

    this.comparisonTarget.innerHTML = "";
    this.comparisonTarget.classList.add("hidden");
  }

  #highlightMoveRow() {
    if (!this.hasMoveRowTarget) {
      return;
    }

    const activePly = this.#currentMove()?.ply;

    this.moveRowTargets.forEach((row) => {
      const isActive = Number(row.dataset.ply) === activePly;

      row.classList.toggle("bg-gray-100", isActive);
      row.classList.toggle("ring-2", isActive);
      row.classList.toggle("ring-inset", isActive);
      row.classList.toggle("ring-gray-400", isActive);
    });
  }

  #isMistakeMove(move) {
    if (!move.played_by_user || !move.classification) {
      return false;
    }

    if (this.mistakeFilter) {
      return move.classification === this.mistakeFilter;
    }

    return MISTAKE_CLASSIFICATIONS.includes(move.classification);
  }

  #mistakeIndices() {
    return this.moves.reduce((indices, move, index) => {
      if (this.#isMistakeMove(move)) {
        indices.push(index + 1);
      }

      return indices;
    }, []);
  }

  #jumpToNextMistake(direction) {
    const indices = this.#mistakeIndices();

    if (indices.length === 0) {
      return;
    }

    const currentPosition = indices.indexOf(this.currentIndex);
    let nextPosition;

    if (currentPosition === -1) {
      nextPosition = direction > 0 ? 0 : indices.length - 1;
    } else {
      nextPosition =
        (currentPosition + direction + indices.length) % indices.length;
    }

    this.currentIndex = indices[nextPosition];

    this.#renderPosition();
  }

  #updateFilterButtons() {
    this.element
      .querySelectorAll("[data-game-review-classification-param]")
      .forEach((button) => {
        const classification = button.dataset.gameReviewClassificationParam;
        const isActive = this.mistakeFilter === classification;

        button.classList.toggle("bg-gray-900", isActive);
        button.classList.toggle("text-white", isActive);
        button.classList.toggle("border-gray-900", isActive);
      });
  }
}
