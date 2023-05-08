package org.korpora.aeet.ediarum;

import net.sf.saxon.s9api.*;
import org.korpora.useful.XMLUtilities;
import org.w3c.dom.Document;
import org.xml.sax.InputSource;

import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;
import javax.xml.transform.sax.SAXSource;
import java.io.*;
import java.nio.file.Path;
import java.util.concurrent.Callable;

import picocli.CommandLine;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;
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
    @Parameters(index = "1", paramLabel = "Type",
            description = "Index Type," + " one of: ${COMPLETION-CANDIDATES} [default: ${DEFAULT-VALUE}]",
            defaultValue = "guess")
    private IndexType indexTypeEnum;

    @Option(names = {"-C", "--copy-original"})
    private boolean copyOriginal;

    @Option(names = {"-o", "--outfile"})
    Path outFile;

    public static void main(String[] args) {
        int exitCode = new CommandLine(new IndexFormatter()).execute(args);
        System.exit(exitCode);
    }

    public Integer call() {
        System.err.format("Going to format '%s' [type '%s']\n", inputFile, indexTypeEnum.toString());
        try {
            OutputStream outPut = (outFile == null) ? System.out : new FileOutputStream(outFile.toFile());
            outPut.write(format(indexTypeEnum, inputFile.toFile(), copyOriginal).getBytes());
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        return 0;
    }

    /**
     * format index; pass arguments as String. Validation by recasting.
     *
     * @param indexTypeString the index type, refer to {@link IndexType}.
     * @param inputFile       the index file
     * @param copyOriginal    whether to copy the original node
     * @return
     */
    @SuppressWarnings("unused")
    private static Document formatDocument(String indexTypeString, String inputFile, boolean copyOriginal) {
        var indexTypeEnum = IndexType.valueOf(indexTypeString);
        var inputFilePath = Path.of(inputFile);
        return formatDocument(indexTypeEnum, inputFilePath.toFile(), copyOriginal);
    }

    /**
     * format index to XML
     *
     * @param indexType     the index type, refer to {@link IndexType}.
     * @param inputFilePath the index file
     * @return
     */
    @SuppressWarnings("unused")
    private static Document formatDocument(IndexType indexType, Path inputFilePath) {
        return formatDocument(indexType, inputFilePath.toFile(), false);
    }

    /**
     * format index; pass arguments as String. Validation by recasting.
     *
     * @param indexTypeString the index type, refer to {@link IndexType}.
     * @param inputFile       the index file
     * @param copyOriginal    whether to copy the original node
     * @return
     */
    @SuppressWarnings("unused")
    private static String format(String indexTypeString, String inputFile, boolean copyOriginal) {
        var indexTypeEnum = IndexType.valueOf(indexTypeString);
        var inputFilePath = Path.of(inputFile);
        return format(indexTypeEnum, inputFilePath.toFile(), copyOriginal);
    }

    /**
     * format index to XML
     *
     * @param indexType     the index type, refer to {@link IndexType}.
     * @param inputFilePath the index file
     * @return
     */
    @SuppressWarnings("unused")
    private static String format(IndexType indexType, Path inputFilePath) {
        return format(indexType, inputFilePath.toFile(), false);
    }

    /**
     * format index of specific entries to simple XML list with items
     *
     * @param indexType    the index type, refer to {@link IndexType}.
     * @param inputFile    the index file
     * @param copyOriginal whether to copy the original node
     * @return
     */
    private static String format(IndexType indexType, File inputFile, boolean copyOriginal) {
        Document document = formatDocument(indexType, inputFile, copyOriginal);
        return XMLUtilities.documentToString(document, true, false);
    }

    /**
     * format index of specific entries to simple XML list with items
     *
     * @param indexType    the index type, refer to {@link IndexType}.
     * @param inputFile    the index file
     * @param copyOriginal whether to copy the original node
     * @return
     */
    private static Document formatDocument(IndexType indexType, File inputFile, boolean copyOriginal) {
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
            queryEvaluator.setExternalVariable(new QName("ediarum-index-id-override"),
                    new XdmAtomicValue(indexTypeString));
            queryEvaluator.setExternalVariable(new QName("copy-original"), new XdmAtomicValue(copyOriginal));
            queryEvaluator.setExternalVariable(new QName("entries"), proc.newDocumentBuilder().wrap(indexSource));
            queryEvaluator.run(new DOMDestination(document));

            return document;


        } catch (IOException | SaxonApiException | ParserConfigurationException e) {
            throw new RuntimeException(e);
        }
    }
}