# @author Mike Bland (michael.bland@gsa.gov)

require_relative '../lib/guides_style_18f/navigation'

require 'fileutils'
require 'minitest/autorun'
require 'safe_yaml'
require 'stringio'

module GuidesStyle18F
  # rubocop:disable ClassLength
  class NavigationTest < ::Minitest::Test
    attr_reader :testdir, :config_path, :pages_dir

    TEST_DIR = File.dirname(__FILE__)
    TEST_PAGES_DIR = File.join TEST_DIR, '_pages'

    NAV_DATA_PATH = File.join(TEST_DIR, 'navigation_test_data.yml')
    NAV_YAML = File.read(NAV_DATA_PATH)
    NAV_DATA = SafeYAML.load(NAV_YAML, safe: true)

    NAV_DATA_WITHOUT_COLLECTIONS_PATH = File.join(
      TEST_DIR, 'navigation_test_data_without_collections.yml')
    NAV_YAML_WITHOUT_COLLECTIONS = File.read(NAV_DATA_WITHOUT_COLLECTIONS_PATH)
    NAV_DATA_WITHOUT_COLLECTIONS = SafeYAML.load(
      NAV_YAML_WITHOUT_COLLECTIONS, safe: true)

    def setup
      @testdir = Dir.mktmpdir
      @config_path = File.join testdir, '_config.yml'
      @pages_dir = File.join testdir, '_pages'
      FileUtils.mkdir_p pages_dir
    end

    def teardown
      FileUtils.remove_entry testdir
    end

    def write_config(config_data)
      File.write config_path, config_data
    end

    def read_config
      File.read config_path
    end

    def copy_pages(pages)
      pages.each do |page|
        parent_dir = File.dirname(page)
        full_orig_path = File.join(TEST_PAGES_DIR, page)
        target_dir = File.join(pages_dir, parent_dir)
        FileUtils.mkdir_p(target_dir)
        FileUtils.cp(full_orig_path, target_dir)
      end
    end

    def nav_array_to_hash(nav)
      (nav['navigation'] || []).map { |i| [i['text'], i] }.to_h
    end

    def assert_result_matches_expected_config(nav_data)
      # We can't do a straight string comparison, since the items may not be
      # in order relative to the original.
      result = read_config
      result_data = SafeYAML.load(result, safe: true)
      refute_equal(-1, result.index(LEADING_COMMENT),
        'Comment before `navigation:` section is missing')
      refute_equal(-1, result.index(TRAILING_COMMENT),
        'Comment after `navigation:` section is missing')
      assert_equal nav_array_to_hash(nav_data), nav_array_to_hash(result_data)
    end

    def test_empty_config_no_pages
      write_config ''
      GuidesStyle18F.update_navigation_configuration @testdir
      assert_equal '', read_config
    end

    def test_empty_config_no_nav_data_no_pages
      write_config ''
      GuidesStyle18F.update_navigation_configuration @testdir
      assert_equal '', read_config
    end

    def test_config_with_nav_data_but_no_pages
      write_config NAV_YAML
      GuidesStyle18F.update_navigation_configuration @testdir
      assert_equal NAV_YAML, read_config
    end

    def test_all_pages_with_existing_data
      write_config NAV_YAML
      copy_pages ALL_PAGES
      GuidesStyle18F.update_navigation_configuration testdir
      assert_equal NAV_YAML, read_config
    end

    ALL_PAGES = %w(
      add-a-new-page/make-a-child-page.md
      add-a-new-page.md
      add-images.md
      github-setup.md
      index.md
      post-your-guide.md
      update-the-config-file/understanding-baseurl.md
      update-the-config-file.md
    )
    COLLECTIONS_CONFIG = [
      'collections:',
      '  pages:',
      '    output: true',
      '    permalink: /:path/',
    ].join("\n")
    LEADING_COMMENT = '' \
      '# Comments before the navigation section should be preserved.'
    TRAILING_COMMENT = '' \
      "# Comments after the navigation section should also be preserved.\n"

    # We need to be careful not to modify the original NAV_DATA object when
    # sorting.
    def sorted_nav_data(nav_data)
      nav_data = {}.merge(nav_data)
      sorted = nav_data['navigation'].map { |i| i }.sort_by { |i| i['text'] }
      nav_data['navigation'] = sorted
      nav_data
    end

    def test_add_all_pages_from_scratch
      write_config([
        COLLECTIONS_CONFIG,
        LEADING_COMMENT,
        'navigation:',
        TRAILING_COMMENT,
      ].join("\n"))
      copy_pages(ALL_PAGES)
      GuidesStyle18F.update_navigation_configuration testdir
      assert_result_matches_expected_config(sorted_nav_data(NAV_DATA))
    end

    def test_add_all_pages_from_scratch_without_collection
      @pages_dir = File.join(testdir, 'pages')
      FileUtils.mkdir_p pages_dir
      config = [
        'permalink: /:path/', LEADING_COMMENT, 'navigation:', TRAILING_COMMENT
      ].join("\n")
      write_config(config)
      copy_pages(ALL_PAGES)
      GuidesStyle18F.update_navigation_configuration testdir
      assert_result_matches_expected_config(
        sorted_nav_data(NAV_DATA_WITHOUT_COLLECTIONS))
    end

    CONFIG_WITH_MISSING_PAGES = [
      COLLECTIONS_CONFIG,
      LEADING_COMMENT,
      'navigation:',
      '- text: Introduction',
      '  internal: true',
      '- text: Add a new page',
      '  url: add-a-new-page/',
      '  internal: true',
      '  children:',
      '  - text: Make a child page',
      '    url: make-a-child-page/',
      '    internal: false',
      TRAILING_COMMENT,
    ].join "\n"

    def test_add_missing_pages
      write_config CONFIG_WITH_MISSING_PAGES
      copy_pages ALL_PAGES
      GuidesStyle18F.update_navigation_configuration testdir
      assert_result_matches_expected_config(NAV_DATA)
    end

    CONFIG_MISSING_CHILD_PAGES = [
      COLLECTIONS_CONFIG,
      LEADING_COMMENT,
      'navigation:',
      '- text: Introduction',
      '  internal: true',
      '- text: Add a new page',
      '  url: add-a-new-page/',
      '  internal: true',
      '- text: Add images',
      '  url: add-images/',
      '  internal: true',
      '- text: Update the config file',
      '  url: update-the-config-file/',
      '  internal: true',
      '- text: GitHub setup',
      '  url: github-setup/',
      '  internal: true',
      '- text: Post your guide',
      '  url: post-your-guide/',
      '  internal: true',
      TRAILING_COMMENT,
    ].join "\n"

    def test_add_missing_child_pages
      write_config CONFIG_MISSING_CHILD_PAGES
      copy_pages ALL_PAGES
      GuidesStyle18F.update_navigation_configuration testdir
      assert_result_matches_expected_config(NAV_DATA)
    end

    CONFIG_MISSING_PARENT_PAGE = [
      COLLECTIONS_CONFIG,
      LEADING_COMMENT,
      'navigation:',
      '- text: Introduction',
      '  internal: true',
      '- text: Add images',
      '  url: add-images/',
      '  internal: true',
      '- text: Make a child page',
      '  url: make-a-child-page/',
      '  internal: true',
      '- text: Update the config file',
      '  url: update-the-config-file/',
      '  internal: true',
      '- text: GitHub setup',
      '  url: github-setup/',
      '  internal: true',
      '- text: Post your guide',
      '  url: post-your-guide/',
      '  internal: true',
      TRAILING_COMMENT,
    ].join "\n"

    # An entry for the child already exists, and we want to move it under a
    # parent page, under the presumption that the parent relationship was just
    # added.
    def test_add_missing_parent_page
      write_config CONFIG_MISSING_PARENT_PAGE
      copy_pages ALL_PAGES
      GuidesStyle18F.update_navigation_configuration testdir
      assert_result_matches_expected_config(NAV_DATA)
    end

    def test_should_raise_if_parent_page_does_not_exist
      write_config CONFIG_MISSING_PARENT_PAGE
      copy_pages ALL_PAGES.reject { |page| page == 'add-a-new-page.md' }
      exception = assert_raises(StandardError) do
        GuidesStyle18F.update_navigation_configuration testdir
      end
      expected = 'Parent page not present in existing config: ' \
        '"Add a new page" needed by: "Make a child page"'
      assert_equal expected, exception.message
    end

    CONFIG_CONTAINING_ONLY_INTRODUCTION = [
      COLLECTIONS_CONFIG,
      LEADING_COMMENT,
      'navigation:',
      '- text: Introduction',
      '  internal: true',
      TRAILING_COMMENT,
    ].join "\n"

    def test_all_pages_starting_with_empty_data
      write_config CONFIG_CONTAINING_ONLY_INTRODUCTION
      copy_pages ALL_PAGES
      GuidesStyle18F.update_navigation_configuration testdir
      assert_result_matches_expected_config(NAV_DATA)
    end

    MISSING_TITLE = <<MISSING_TITLE
---
other_property: other value
---
MISSING_TITLE

    NO_LEADING_SLASH = <<NO_LEADING_SLASH
---
title: No leading slash
permalink: no-leading-slash/
---
NO_LEADING_SLASH

    NO_TRAILING_SLASH = <<NO_TRAILING_SLASH
---
title: No trailing slash
permalink: /no-trailing-slash
---
NO_TRAILING_SLASH

    FILES_WITH_ERRORS = {
      'missing-front-matter.md' => 'no front matter brosef',
      'missing-title.md' => MISSING_TITLE,
      'no-leading-slash.md' => NO_LEADING_SLASH,
      'no-trailing-slash.md' => NO_TRAILING_SLASH,
    }

    EXPECTED_ERRORS = <<EXPECTED_ERRORS
The following files have errors in their front matter:
  _pages/missing-front-matter.md:
    no front matter defined
  _pages/missing-title.md:
    no `title:` property
  _pages/no-leading-slash.md:
    `permalink:` does not begin with '/'
  _pages/no-trailing-slash.md:
    `permalink:` does not end with '/'
EXPECTED_ERRORS

    def write_page(filename, content)
      File.write File.join(pages_dir, filename), content
    end

    def test_detect_front_matter_errors
      write_config NAV_YAML
      FILES_WITH_ERRORS.each { |file, content| write_page file, content }
      errors = GuidesStyle18F::FrontMatter.validate_with_message_upon_error(
        GuidesStyle18F::FrontMatter.load(testdir))
      assert_equal EXPECTED_ERRORS, errors + "\n"
    end

    def _test_show_error_message_and_exit_if_pages_front_matter_is_malformed
      orig_stderr, $stderr = $stderr, StringIO.new
      write_config "#{COLLECTIONS_CONFIG}\nnavigation:"
      FILES_WITH_ERRORS.each { |file, content| write_page file, content }
      exception = assert_raises(SystemExit) do
        GuidesStyle18F.update_navigation_configuration testdir
      end
      assert_equal 1, exception.status
      assert_equal EXPECTED_ERRORS + "_config.yml not updated\n", $stderr.string
    ensure
      $stderr = orig_stderr
    end
  end
  # rubocop:enable ClassLength
end
