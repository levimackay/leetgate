import Foundation

/// The v1 curriculum: Easy problems grouped by pattern, in the order they should
/// be attempted. Pattern-contiguous on purpose — solving four problems that share
/// a shape is what makes the shape transfer.
///
/// `two-sum` leads deliberately. It is the problem most likely to have been
/// transcribed rather than derived, so re-deriving it cold is the first honest rep.
public enum Seed {
    public static let problems: [SeedProblem] = raw.enumerated().map { index, entry in
        SeedProblem(slug: entry.0, title: entry.1, difficulty: .easy, pattern: entry.2, seq: index)
    }

    private static let raw: [(String, String, String)] = [
        ("two-sum", "Two Sum", "Arrays & Hashing"),
        ("contains-duplicate", "Contains Duplicate", "Arrays & Hashing"),
        ("valid-anagram", "Valid Anagram", "Arrays & Hashing"),
        ("majority-element", "Majority Element", "Arrays & Hashing"),

        ("valid-palindrome", "Valid Palindrome", "Two Pointers"),
        ("merge-sorted-array", "Merge Sorted Array", "Two Pointers"),
        ("remove-duplicates-from-sorted-array", "Remove Duplicates from Sorted Array", "Two Pointers"),
        ("move-zeroes", "Move Zeroes", "Two Pointers"),

        ("best-time-to-buy-and-sell-stock", "Best Time to Buy and Sell Stock", "Sliding Window"),

        ("valid-parentheses", "Valid Parentheses", "Stack"),
        ("min-stack", "Min Stack", "Stack"),

        ("binary-search", "Binary Search", "Binary Search"),
        ("search-insert-position", "Search Insert Position", "Binary Search"),
        ("first-bad-version", "First Bad Version", "Binary Search"),

        ("reverse-linked-list", "Reverse Linked List", "Linked List"),
        ("merge-two-sorted-lists", "Merge Two Sorted Lists", "Linked List"),
        ("linked-list-cycle", "Linked List Cycle", "Linked List"),
        ("middle-of-the-linked-list", "Middle of the Linked List", "Linked List"),

        ("invert-binary-tree", "Invert Binary Tree", "Trees"),
        ("maximum-depth-of-binary-tree", "Maximum Depth of Binary Tree", "Trees"),
        ("same-tree", "Same Tree", "Trees"),
        ("subtree-of-another-tree", "Subtree of Another Tree", "Trees"),
        ("diameter-of-binary-tree", "Diameter of Binary Tree", "Trees"),
        ("balanced-binary-tree", "Balanced Binary Tree", "Trees"),

        ("kth-largest-element-in-a-stream", "Kth Largest Element in a Stream", "Heap"),
        ("last-stone-weight", "Last Stone Weight", "Heap"),

        ("single-number", "Single Number", "Bit Manipulation"),
        ("number-of-1-bits", "Number of 1 Bits", "Bit Manipulation"),
        ("counting-bits", "Counting Bits", "Bit Manipulation"),
        ("missing-number", "Missing Number", "Bit Manipulation"),

        ("climbing-stairs", "Climbing Stairs", "1-D Dynamic Programming"),
    ]
}
