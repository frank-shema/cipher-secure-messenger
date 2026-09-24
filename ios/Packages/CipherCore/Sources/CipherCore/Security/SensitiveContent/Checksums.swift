import Foundation

/// Checksum algorithms used to tell real account numbers from random digit runs. Both are
/// public-domain arithmetic; they exist to cut false positives, not as security controls.
enum Checksums {
    /// Luhn (ISO/IEC 7812-1) check used by every major payment card scheme. Rejects sequences of one
    /// repeated digit because "0000 0000 0000 0000" passes Luhn yet is never a card.
    static func passesLuhn(_ digits: String) -> Bool {
        var sum = 0
        var doubleIt = false
        var distinct = Set<Character>()
        for character in digits.reversed() {
            guard let value = character.wholeNumberValue else { return false }
            distinct.insert(character)
            var contribution = value
            if doubleIt {
                contribution *= 2
                if contribution > 9 { contribution -= 9 }
            }
            sum += contribution
            doubleIt.toggle()
        }
        return distinct.count > 1 && sum % 10 == 0
    }

    /// ISO 13616 IBAN check: rotate the first four characters to the end, expand letters to two-digit
    /// values (A=10…Z=35) and the whole number must be ≡ 1 (mod 97). Computed digit by digit so a
    /// 34-character IBAN never overflows an integer.
    static func passesIBANMod97(_ normalized: String) -> Bool {
        guard normalized.count >= 5 else { return false }
        let rotated = String(normalized.dropFirst(4)) + String(normalized.prefix(4))
        var remainder = 0
        for character in rotated {
            let expanded: String
            if let digit = character.wholeNumberValue {
                expanded = String(digit)
            } else if let ascii = character.asciiValue, character.isLetter {
                expanded = String(Int(ascii) - 55)
            } else {
                return false
            }
            for digitCharacter in expanded {
                guard let digit = digitCharacter.wholeNumberValue else { return false }
                remainder = (remainder * 10 + digit) % 97
            }
        }
        return remainder == 1
    }

    /// Shannon entropy in bits per character. Random-looking tokens sit above ~3.5; English words and
    /// repeated characters well below.
    static func shannonEntropy(_ token: Substring) -> Double {
        guard !token.isEmpty else { return 0 }
        var counts: [Character: Int] = [:]
        for character in token {
            counts[character, default: 0] += 1
        }
        let length = Double(token.count)
        return counts.values.reduce(0.0) { partial, count in
            let probability = Double(count) / length
            return partial - probability * log2(probability)
        }
    }
}
