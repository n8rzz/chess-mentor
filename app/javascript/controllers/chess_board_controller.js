import { Controller } from "@hotwired/stimulus";
import {
  Chessboard,
  COLOR,
  INPUT_EVENT_TYPE,
  FEN,
  Markers,
  Arrows,
  ARROW_TYPE,
} from "cm-chessboard";
import { Chess } from "chess.js";

const ASSETS_URL = "/cm-chessboard/assets/";

const MARKER_CIRCLE_PRIMARY = {
  class: "marker-circle-primary",
  slice: "markerCircle",
};

export default class extends Controller {
  static targets = ["container"];
  static values = {
    fen: { type: String, default: FEN.start },
    orientation: { type: String, default: "white" },
    interactive: { type: Boolean, default: false },
  };

  #moveInputHandler = null;

  async connect() {
    this.chess = new Chess(
      this.fenValue === FEN.start ? undefined : this.fenValue,
    );
    this.board = new Chessboard(this.containerTarget, {
      position: this.fenValue,
      orientation:
        this.orientationValue === "black" ? COLOR.black : COLOR.white,
      responsive: true,
      assetsUrl: ASSETS_URL,
      assetsCache: false,
      style: {
        pieces: {
          file: "/cm-chessboard/assets/pieces/standard.svg",
        },
      },
      extensions: [{ class: Markers }, { class: Arrows }],
    });

    if (this.interactiveValue) {
      this.enableInput(this.orientationValue);
    }

    this.dispatch("ready");
  }

  disconnect() {
    this.board?.destroy();

    this.board = null;
    this.chess = null;
  }

  fenValueChanged() {
    if (!this.board) {
      return;
    }

    this.setPosition(this.fenValue);
  }

  async resetToFen(fen) {
    this.disableInput();

    await this.board?.setPosition(fen, false);

    this.chess = new Chess(fen === FEN.start ? undefined : fen);

    this.board?.removeArrows();
    this.board?.removeMarkers();

    if (this.interactiveValue) {
      this.enableInput(this.orientationValue);
    }
  }

  setPosition(fen, { animated = false } = {}) {
    this.chess = new Chess(fen === FEN.start ? undefined : fen);

    this.board?.setPosition(fen, animated);
    this.board?.removeArrows();
    this.board?.removeMarkers();
  }

  showArrows(arrows = []) {
    this.board?.removeArrows();

    arrows.forEach(({ from, to, type = "success" }) => {
      const arrowType = ARROW_TYPE[type] || ARROW_TYPE.success;

      this.board?.addArrow(arrowType, from, to);
    });
  }

  showHintMarker(square) {
    this.board?.removeMarkers();

    if (square) {
      this.board?.addMarker(MARKER_CIRCLE_PRIMARY, square);
    }
  }

  clearMarkers() {
    this.board?.removeMarkers();
  }

  playUci(uci) {
    const from = uci.slice(0, 2);
    const to = uci.slice(2, 4);
    const promotion = uci.length > 4 ? uci[4] : undefined;
    const move = this.chess.move({ from, to, promotion });

    if (move) {
      this.board.setPosition(this.chess.fen(), true);
    }

    return move;
  }

  enableInput(color = null) {
    if (!this.board || this.board.isMoveInputEnabled()) {
      return;
    }

    if (!this.#moveInputHandler) {
      this.#moveInputHandler = this.#handleMoveInput.bind(this);
    }

    this.board.enableMoveInput(
      this.#moveInputHandler,
      this.#inputColorFor(color),
    );
  }

  disableInput() {
    this.board?.disableMoveInput();
  }

  #inputColorFor(color) {
    if (color === "black") {
      return COLOR.black;
    }

    if (color === "white") {
      return COLOR.white;
    }
  }

  #handleMoveInput(event) {
    if (event.type === INPUT_EVENT_TYPE.moveInputStarted) {
      return true;
    }

    if (event.type !== INPUT_EVENT_TYPE.validateMoveInput) {
      return;
    }

    const move = this.#applyMove(event.squareFrom, event.squareTo);

    if (!move) {
      return false;
    }

    this.board?.setPosition(this.chess.fen(), false);
    this.#emitMove(move);

    // We applied the move via chess.js + setPosition. Returning false prevents
    // cm-chessboard from also calling movePiece, which desyncs board state.
    return false;
  }

  #applyMove(from, to) {
    try {
      return this.chess.move({ from, to, promotion: "q" });
    } catch {
      return null;
    }
  }

  #emitMove(move) {
    const uci = move.from + move.to + (move.promotion || "");

    this.element.dispatchEvent(
      new CustomEvent("chess-board:move", {
        bubbles: true,
        detail: {
          uci,
          san: move.san,
          fen: this.chess.fen(),
        },
      }),
    );
  }
}
