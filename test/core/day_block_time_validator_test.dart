import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/core/utils/day_block_time_validator.dart';
import 'package:ritual/data/models/block_type.dart';
import 'package:ritual/data/models/day_block.dart';

void main() {
  group('DayBlockTimeValidator.parseTime', () {
    test('parse valid HH:mm values', () {
      expect(
        DayBlockTimeValidator.parseTime('07:45'),
        const TimeOfDay(hour: 7, minute: 45),
      );
    });

    test('reject invalid numeric ranges', () {
      expect(DayBlockTimeValidator.parseTime('24:00'), isNull);
      expect(DayBlockTimeValidator.parseTime('12:60'), isNull);
    });

    test('reject malformed values', () {
      expect(DayBlockTimeValidator.parseTime('abc'), isNull);
      expect(DayBlockTimeValidator.parseTime('7-45'), isNull);
    });
  });

  group('DayBlockTimeValidator.validateTimeRange', () {
    final existingBlocks = [
      DayBlock(
        start: '08:00',
        end: '09:00',
        title: 'Trabajo',
        type: BlockType.commitment,
      ),
      DayBlock(
        start: '10:00',
        end: '11:00',
        title: 'Curso',
        type: BlockType.habit,
      ),
    ];

    test('require both start and end', () {
      expect(
        DayBlockTimeValidator.validateTimeRange(
          start: '',
          end: '09:00',
          existingBlocks: existingBlocks,
        ),
        'Selecciona hora de inicio y fin.',
      );
    });

    test('reject zero or negative durations', () {
      expect(
        DayBlockTimeValidator.validateTimeRange(
          start: '09:00',
          end: '09:00',
          existingBlocks: existingBlocks,
        ),
        'La hora de fin debe ser mayor que la de inicio.',
      );
    });

    test('reject overlapping blocks', () {
      expect(
        DayBlockTimeValidator.validateTimeRange(
          start: '08:30',
          end: '09:30',
          existingBlocks: existingBlocks,
        ),
        'Este bloque se traslapa con otro bloque existente.',
      );
    });

    test('allow editing the same block without self-overlap', () {
      expect(
        DayBlockTimeValidator.validateTimeRange(
          start: '08:00',
          end: '09:00',
          existingBlocks: existingBlocks,
          blockBeingEdited: existingBlocks.first,
        ),
        isNull,
      );
    });

    test('allow editing a cloned block with the same id', () {
      final clonedBlock = existingBlocks.first.copyWith();

      expect(
        DayBlockTimeValidator.validateTimeRange(
          start: '08:00',
          end: '09:00',
          existingBlocks: existingBlocks,
          blockBeingEdited: clonedBlock,
        ),
        isNull,
      );
    });

    test('accept non-overlapping valid ranges', () {
      expect(
        DayBlockTimeValidator.validateTimeRange(
          start: '09:00',
          end: '10:00',
          existingBlocks: existingBlocks,
        ),
        isNull,
      );
    });
  });
}
