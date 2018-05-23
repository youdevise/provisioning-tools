require 'provisioning-tools/util/xml_utils'

describe Util::VirshDomainXmlDiffer do
  it 'fails if xml node name is different' do
    xml_diff = Util::VirshDomainXmlDiffer.new("<foo/>", "<bar/>")
    xml_diff.differences.should eql(["Node name difference. Expected: /foo Actual: /bar"])
  end

  it 'describes where text is missing' do
    expected = "<a>foo</a>"
    actual = "<a/>"

    xml_diff = Util::VirshDomainXmlDiffer.new(expected, actual)
    xml_diff.differences.should eql(["Node value difference. Expected /a to have text \"foo\", but it has no text."])
  end

  it 'describes where text is unexpected' do
    expected = "<a/>"
    actual = "<a>foo</a>"

    xml_diff = Util::VirshDomainXmlDiffer.new(expected, actual)
    xml_diff.differences.should eql(["Node value difference. Expected /a to have no text, but it has text \"foo\"."])
  end

  it 'describes where text is different' do
    expected = "<a>foo</a>"
    actual = "<a>bar</a>"

    xml_diff = Util::VirshDomainXmlDiffer.new(expected, actual)

    xml_diff.differences.should eql(["Node value difference. Expected /a to have text \"foo\", but it has text \"bar\"."])
  end

  it 'ignores where text is blank' do
    expected = "<a></a>"
    actual = "<a>         \n      </a>"

    xml_diff = Util::VirshDomainXmlDiffer.new(expected, actual)

    xml_diff.differences.should eql([])
  end

  it 'describes where attributes are missing' do
    expected = "<a foo='one'/>"
    actual = "<a/>"

    xml_diff = Util::VirshDomainXmlDiffer.new(expected, actual)
    xml_diff.differences.should eql(["Attribute difference. Expected /a to have attribute \"foo=one\", but it has no attribute \"foo\"."])
  end

  it 'describes where attributes are unexpected' do
    expected = "<a/>"
    actual = "<a foo='two'/>"

    xml_diff = Util::VirshDomainXmlDiffer.new(expected, actual)
    xml_diff.differences.should eql(["Attribute difference. Expected /a to have no attribute \"foo\", but it has attribute \"foo=two\"."])
  end

  it 'describes where attributes are different' do
    expected = "<a foo='one'/>"
    actual = "<a foo='two'/>"

    xml_diff = Util::VirshDomainXmlDiffer.new(expected, actual)
    xml_diff.differences.should eql(["Attribute difference. Expected /a to have attribute \"foo=one\", but it has attribute \"foo=two\"."])
  end

  it 'describes where elements are missing' do
    expected = "<a><b/><b/><b/></a>"
    actual = "<a><b/><b/></a>"

    xml_diff = Util::VirshDomainXmlDiffer.new(expected, actual)

    xml_diff.differences.should eql(["Missing element \"/a/b\" (expected 3, actual 2)."])
  end

  it 'describes where elements are unexpected' do
    expected = "<a><b/><b/></a>"
    actual = "<a><b/><b/><b/></a>"

    xml_diff = Util::VirshDomainXmlDiffer.new(expected, actual)

    xml_diff.differences.should eql(["Unexpected element \"/a/b\" (expected 2, actual 3)."])
  end

  it 'diffs complex stuff' do
    expected = File.open(File.join(File.dirname(__FILE__), "example1.xml")).read
    actual = File.open(File.join(File.dirname(__FILE__), "example2.xml")).read

    xml_diff = Util::VirshDomainXmlDiffer.new(expected, actual)

    xml_diff.differences.should eql([
      "Unexpected element \"/domain/clock\" (expected 0, actual 1).",
      "Missing element \"/domain/devices/input\" (expected 2, actual 1).",
      "Attribute difference. Expected /domain/devices/interface/address to have attribute \"type=pci\", but it has attribute \"type=scsi\"."
    ])
  end

  it 'ignores excluded things' do
    expected = "<domain>"\
               "  <devices>"\
               "    <interface type='bridge'>"\
               "      <mac/>"\
               "    </interface>"\
               "  </devices>"\
               "</domain>"
    actual = "<domain id='4'>"\
             "  <uuid>beef</uuid>"\
             "  <resource/>"\
             "  <seclabel/>"\
             "  <devices>"\
             "    <interface type='bridge'>"\
             "      <mac address='dead'/>"\
             "    </interface>"\
             "    <input type='keyboard' bus='ps2'/>"\
             "  </devices>"\
             "</domain>"

    xml_diff = Util::VirshDomainXmlDiffer.new(expected, actual)
    xml_diff.differences.should eql([])
  end

  it 'checks things that are not ignored, but are similar to those that are ignored' do
    expected = "<domain>"\
               "  <id>4</id>"\
               "  <devices>"\
               "    <uuid>fee</uuid>"\
               "  </devices>"\
               "</domain>"
    actual = "<domain idx='4'>"\
             "  <id>5</id>"\
             "  <devices>"\
             "    <uuid>beef</uuid>"\
             "    <input type='mouse' bus='ps2'/>"\
             "  </devices>"\
             "</domain>"

    xml_diff = Util::VirshDomainXmlDiffer.new(expected, actual)
    xml_diff.differences.should eql([
      "Attribute difference. Expected /domain to have no attribute \"idx\", but it has attribute \"idx=4\".",
      "Node value difference. Expected /domain/id to have text \"4\", but it has text \"5\".",
      "Unexpected element \"/domain/devices/input\" (expected 0, actual 1).",
      "Node value difference. Expected /domain/devices/uuid to have text \"fee\", but it has text \"beef\"."
    ])
  end
end
