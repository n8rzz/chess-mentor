# frozen_string_literal: true

class ConvertMotifAndPhaseToEnums < ActiveRecord::Migration[8.1]
  MOTIF_MAP = {
    "fork" => 0,
    "pin" => 1,
    "skewer" => 2,
    "double_attack" => 3,
    "discovered_attack" => 4,
    "discovered_check" => 5,
    "back_rank_mate" => 6,
    "back_rank" => 6,
    "removal_of_defender" => 7,
    "deflection" => 8,
    "decoy" => 9,
    "overloaded_piece" => 10,
    "zwischenzug" => 11,
    "mate_threat" => 12,
    "undefended_piece" => 13,
    "sacrifice" => 14,
    "piece_activity" => 15,
    "center_control" => 16,
    "exposed_king" => 17,
    "castling_break" => 18,
    "material_loss" => 19,
    "isolated_pawn" => 20,
    "passed_pawn" => 21,
    "king_and_pawn" => 22,
    "opposition" => 23,
    "one_move_win" => 24,
    "forcing_line" => 25
  }.freeze

  PHASE_MAP = {
    "opening" => 0,
    "middlegame" => 1,
    "endgame" => 2
  }.freeze

  def up
    add_column :puzzles, :motif_int, :integer

    say_with_time "backfilling puzzles.motif" do
      MOTIF_MAP.each do |string_value, int_value|
        execute <<~SQL.squish
          UPDATE puzzles SET motif_int = #{int_value} WHERE motif = #{quote(string_value)}
        SQL
      end
    end

    if (unmapped = select_value("SELECT COUNT(*) FROM puzzles WHERE motif IS NOT NULL AND motif_int IS NULL").to_i).positive?
      raise "unmapped puzzle motifs remain: #{unmapped}"
    end

    remove_column :puzzles, :motif
    rename_column :puzzles, :motif_int, :motif
    change_column_null :puzzles, :motif, false

    add_column :weakness_events, :phase_int, :integer

    say_with_time "backfilling weakness_events.phase" do
      PHASE_MAP.each do |string_value, int_value|
        execute <<~SQL.squish
          UPDATE weakness_events SET phase_int = #{int_value} WHERE phase = #{quote(string_value)}
        SQL
      end
    end

    if (unmapped = select_value("SELECT COUNT(*) FROM weakness_events WHERE phase IS NOT NULL AND phase_int IS NULL").to_i).positive?
      raise "unmapped weakness event phases remain: #{unmapped}"
    end

    remove_column :weakness_events, :phase
    rename_column :weakness_events, :phase_int, :phase
    change_column_null :weakness_events, :phase, false
  end

  def down
    add_column :puzzles, :motif_str, :string
    add_column :weakness_events, :phase_str, :string

    MOTIF_MAP.each do |string_value, int_value|
      execute <<~SQL.squish
        UPDATE puzzles SET motif_str = #{quote(string_value)} WHERE motif = #{int_value}
      SQL
    end

    PHASE_MAP.each do |string_value, int_value|
      execute <<~SQL.squish
        UPDATE weakness_events SET phase_str = #{quote(string_value)} WHERE phase = #{int_value}
      SQL
    end

    remove_column :puzzles, :motif
    rename_column :puzzles, :motif_str, :motif

    remove_column :weakness_events, :phase
    rename_column :weakness_events, :phase_str, :phase
  end
end
