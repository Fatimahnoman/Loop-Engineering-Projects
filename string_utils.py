"""Utility functions for string manipulation."""


def reverse_string(s):
    """Return the input string with its characters reversed."""
    return s[::-1]


def is_palindrome(text):
    """Return True if the text reads the same forwards and backwards."""
    cleaned = text.lower().replace(" ", "")
    return cleaned == reverse_string(cleaned)