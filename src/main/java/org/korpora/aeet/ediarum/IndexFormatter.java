package org.korpora.aeet.ediarum;

import net.sf.saxon.s9api.*;
import org.korpora.useful.XMLUtilities;
import org.w3c.dom.Document;
import org.xml.sax.InputSource;

import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;
import javax.xml.transform.sax.SAXSource;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Path;
import java.util.concurrent.Callable;

import picocli.CommandLine;
import picocli.CommandLine.Command;
import picocli.CommandLine.Parameters;


/**
 * format  (Ediarum.REGISTER and) TEI-conformant indices to Ediarum.JAR-compatible simple lists.
 *
 * @author Bernhard Fisseni &lt;bernhard.fisseni@uni-due.de&gt;
 */
@Command(mixinStandardHelpOptions = true, description = "format index for Ediarum in Oxygen",
        versionProvider = VersionProvider.class)
public class IndexFormatter implements Callable<Integer> {


    /**
     * kinds of indices supported, names are in sync with {@code index-formatter.xql}
     */
    public enum IndexType {
        persons,
        places,
        items,
        organisations,
        bibliography,
        guess
    }

    @SuppressWarnings("unused")
    @Parameters(index = "0", description = "input file")
    private Path inputFile;

    @SuppressWarnings("unused")
    @Parameters(index = "1", paramLabel = "Type", description = "Index Type,"
            + " one of: ${COMPLETION-CANDIDATES} [default: ${DEFAULT-VALUE}]", defaultValue = "guess")

    private IndexType indexTypeEnum;

    public static void main(String[] args) {
        int exitCode = new CommandLine(new IndexFormatter())
                .execute(args);
        System.exit(exitCode);
    }

    public Integer call() {
        System.out.format("Going to format '%s' [type '%s']\n", inputFile, indexTypeEnum.toString());
        format(indexTypeEnum, inputFile.toFile());
        return 0;
    }

    /**
     * format index; pass arguments as String. Validation by recasting.
     *
     * @param indexTypeString the index type, refer to {@link IndexType}.
     * @param inputFile       the index file
     */
    @SuppressWarnings("unused")
    private static void format(String indexTypeString, String inputFile) {
        var indexTypeEnum = IndexType.valueOf(indexTypeString);
        var inputFilePath = Path.of(inputFile);
        format(indexTypeEnum, inputFilePath.toFile());
    }

    /**
     * format index to XML
     *
     * @param indexType     the index type, refer to {@link IndexType}.
     * @param inputFilePath the index file
     */
    @SuppressWarnings("unused")
    private static void format(IndexType indexType, Path inputFilePath) {
        format(indexType, inputFilePath.toFile());
    }

    /**
     * format index of specific entries to simple XML list with items
     *
     * @param indexType the index type, refer to {@link IndexType}.
     * @param inputFile the index file
     */
    private static void format(IndexType indexType, File inputFile) {
        try (InputStream formatXQL = IndexFormatter.class.getClassLoader().getResourceAsStream("index-formatter.xql");
             InputStream indexStream = new FileInputStream(inputFile)) {
            String indexTypeString = indexType.toString();
            Processor proc = new Processor(false);
            XQueryCompiler comp = proc.newXQueryCompiler();
            XQueryExecutable xQueryEvaluator = comp.compile(formatXQL);

            DocumentBuilderFactory docFactory = DocumentBuilderFactory.newInstance();
            docFactory.setNamespaceAware(true);
            Document document = docFactory.newDocumentBuilder().newDocument();

            SAXSource indexSource = new SAXSource(new InputSource(indexStream));
            XQueryEvaluator queryEvaluator = xQueryEvaluator.load();
            queryEvaluator.setExternalVariable(new QName("ediarum-index-id-external"), new XdmAtomicValue(indexTypeString));
            queryEvaluator.setExternalVariable(new QName("entries"), proc.newDocumentBuilder().wrap(indexSource));
            queryEvaluator.run(new DOMDestination(document));

            System.out.println(XMLUtilities.documentToString(document, true, false));


        } catch (IOException | SaxonApiException | ParserConfigurationException e) {
            throw new RuntimeException(e);
        }
    }
}